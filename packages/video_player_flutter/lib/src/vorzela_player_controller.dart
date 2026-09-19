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
    notifyListeners();

    final id = await _platform.create();
    _playerId = id;
    _events = _platform.eventsFor(id).listen(_onEvent);

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
    notifyListeners();
  }

  void _onEvent(PlayerEvent event) {
    switch (event) {
      case PlayerReadyEvent(:final textureId, :final durationMs, :final levels):
        this.textureId = textureId;
        duration = Duration(milliseconds: durationMs);
        this.levels = levels;
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
