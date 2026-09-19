import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:video_player_flutter_platform_interface/video_player_flutter_platform_interface.dart';

class VorzelaPlayerController extends ChangeNotifier {
  VorzelaPlayerController({VideoPlayerPlatform? platform})
      : _platform = platform ?? VideoPlayerPlatform.instance;

  final VideoPlayerPlatform _platform;

  int? _playerId;
  int? textureId;
  bool isReady = false;
  bool isBuffering = false;
  bool isPlaying = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  Duration buffered = Duration.zero;
  List<QualityLevel> levels = const [];
  String currentQuality = 'auto';
  String? error;
  String? poster;
  int _videoWidth = 0;
  int _videoHeight = 0;

  /// Real decoded aspect ratio (width / height) once known — portrait
  /// short-form (`≈0.56`), landscape (`≈1.78`), square (`1`), etc.
  /// `null` until dimensions arrive with / after `ready`.
  double? get videoAspectRatio =>
      (_videoWidth > 0 && _videoHeight > 0) ? _videoWidth / _videoHeight : null;

  int get videoWidth => _videoWidth;
  int get videoHeight => _videoHeight;

  StreamSubscription<PlayerEvent>? _events;

  Future<void> load(
    String uri, {
    String? poster,
    bool autoPlay = false,
    bool fastStart = true,
    bool capToPlayerSize = true,
    int? viewWidth,
    int? viewHeight,
  }) async {
    await disposePlayer();
    this.poster = poster;
    error = null;
    isReady = false;
    _videoWidth = 0;
    _videoHeight = 0;
    notifyListeners();

    final id = await _platform.create();
    _playerId = id;
    _events = _platform.eventsFor(id).listen(_onEvent);

    try {
      await _platform.load(
        id,
        uri: uri,
        poster: poster,
        autoPlay: autoPlay,
        fastStart: fastStart,
        capToPlayerSize: capToPlayerSize,
        viewWidth: viewWidth,
        viewHeight: viewHeight,
      );
      if (autoPlay) isPlaying = true;
    } catch (e) {
      // Surface native/method-channel failures (bad_args, insecure_uri, …)
      // through the same `error` field UI already listens to.
      error = '$e';
      isPlaying = false;
    }
    notifyListeners();
  }

  void _onEvent(PlayerEvent event) {
    switch (event) {
      case PlayerReadyEvent(
          :final textureId,
          :final durationMs,
          :final levels,
          :final videoWidth,
          :final videoHeight,
        ):
        this.textureId = textureId;
        duration = Duration(milliseconds: durationMs);
        this.levels = levels;
        if (videoWidth > 0) _videoWidth = videoWidth;
        if (videoHeight > 0) _videoHeight = videoHeight;
        isReady = true;
        error = null;
      case PlayerBufferingEvent(:final isBuffering):
        this.isBuffering = isBuffering;
      case PlayerPositionEvent(:final positionMs, :final bufferedMs):
        position = Duration(milliseconds: positionMs);
        buffered = Duration(milliseconds: bufferedMs);
      case PlayerErrorEvent(:final message):
        error = message;
        isPlaying = false;
      case PlayerCompletedEvent():
        isPlaying = false;
        position = duration;
    }
    notifyListeners();
  }

  Future<void> play() async {
    final id = _playerId;
    if (id == null) return;
    await _platform.play(id);
    isPlaying = true;
    notifyListeners();
  }

  Future<void> pause() async {
    final id = _playerId;
    if (id == null) return;
    await _platform.pause(id);
    isPlaying = false;
    notifyListeners();
  }

  Future<void> seek(Duration to) async {
    final id = _playerId;
    if (id == null) return;
    await _platform.seek(id, to.inMilliseconds);
  }

  Future<void> setVolume(double volume) async {
    final id = _playerId;
    if (id == null) return;
    await _platform.setVolume(id, volume.clamp(0.0, 1.0));
  }

  /// [quality] is `"auto"` or a label like `"480p"`.
  Future<void> setQuality(String quality) async {
    final id = _playerId;
    if (id == null) return;
    await _platform.setQuality(id, quality);
    currentQuality = quality;
    notifyListeners();
  }

  Future<void> disposePlayer() async {
    await _events?.cancel();
    _events = null;
    final id = _playerId;
    _playerId = null;
    textureId = null;
    isReady = false;
    isBuffering = false;
    isPlaying = false;
    _videoWidth = 0;
    _videoHeight = 0;
    if (id != null) {
      await _platform.disposePlayer(id);
    }
  }

  @override
  void dispose() {
    unawaited(disposePlayer());
    super.dispose();
  }
}
