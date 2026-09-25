import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:video_player_flutter_platform_interface/video_player_flutter_platform_interface.dart';

/// How a single tap on the player surface is handled (YouTube / TikTok style).
enum VorzelaTapAction {
  /// Toggle play / pause (default for the main [VorzelaPlayer]).
  playPause,

  /// Toggle mute / unmute (useful for hover previews).
  toggleMute,

  /// Enter fullscreen (same as the fullscreen button).
  fullscreen,

  /// Do nothing — host handles gestures.
  none,
}

class VorzelaPlayerController extends ChangeNotifier with WidgetsBindingObserver {
  VorzelaPlayerController({
    VideoPlayerPlatform? platform,
    this.pauseOnBackground = true,
    this.allowsPictureInPicture = false,
  }) : _platform = platform ?? VideoPlayerPlatform.instance {
    WidgetsBinding.instance.addObserver(this);
  }

  final VideoPlayerPlatform _platform;

  /// Pause when the app is backgrounded / inactive (YouTube/TikTok default).
  /// Set `false` only if you handle lifecycle yourself or use PiP.
  final bool pauseOnBackground;

  /// **Opt-in.** If true and the OS supports it, going to background tries
  /// Android Activity PiP instead of pausing — playback can continue over
  /// other apps. Default `false`: no PiP, no overlay permission required.
  final bool allowsPictureInPicture;

  int? _playerId;
  int _loadGeneration = 0;
  int? textureId;
  bool isReady = false;
  bool isBuffering = false;
  bool isPlaying = false;
  bool isMuted = false;
  double volume = 1.0;
  bool isFullscreen = false;
  bool isInPictureInPicture = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  Duration buffered = Duration.zero;
  List<QualityLevel> levels = const [];
  String currentQuality = 'auto';
  String? error;
  String? poster;
  int _videoWidth = 0;
  int _videoHeight = 0;
  bool _wasPlayingBeforeBackground = false;

  double? get videoAspectRatio =>
      (_videoWidth > 0 && _videoHeight > 0) ? _videoWidth / _videoHeight : null;

  int get videoWidth => _videoWidth;
  int get videoHeight => _videoHeight;
  int? get playerId => _playerId;

  StreamSubscription<PlayerEvent>? _events;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        unawaited(_onLeaveForeground());
      case AppLifecycleState.resumed:
        unawaited(_onEnterForeground());
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _onLeaveForeground() async {
    if (isInPictureInPicture) return;
    if (allowsPictureInPicture && isPlaying) {
      final ok = await enterPictureInPicture();
      if (ok) return;
    }
    if (!pauseOnBackground) return;
    _wasPlayingBeforeBackground = isPlaying;
    if (isPlaying) await pause();
  }

  Future<void> _onEnterForeground() async {
    isInPictureInPicture = false;
    if (_wasPlayingBeforeBackground && pauseOnBackground) {
      _wasPlayingBeforeBackground = false;
      await play();
    }
  }

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
    final generation = _loadGeneration;
    this.poster = poster;
    error = null;
    isReady = false;
    _videoWidth = 0;
    _videoHeight = 0;
    notifyListeners();

    final id = await _platform.create();
    if (generation != _loadGeneration) {
      await _platform.disposePlayer(id);
      return;
    }
    _playerId = id;
    final listenPlayerId = id;
    _events = _platform.eventsFor(id).listen(
          (event) => _onEvent(event, generation, listenPlayerId),
        );

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
      if (generation != _loadGeneration) return;
      if (autoPlay) isPlaying = true;
      if (isMuted) {
        await _platform.setVolume(id, 0);
      } else {
        await _platform.setVolume(id, volume);
      }
    } catch (e) {
      if (generation != _loadGeneration) return;
      error = '$e';
      isPlaying = false;
      await disposePlayer();
    }
    if (generation == _loadGeneration) notifyListeners();
  }

  void _onEvent(PlayerEvent event, int generation, int listenPlayerId) {
    if (generation != _loadGeneration ||
        _playerId == null ||
        _playerId != listenPlayerId) {
      return;
    }
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

  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seek(Duration to) async {
    final id = _playerId;
    if (id == null) return;
    await _platform.seek(id, to.inMilliseconds);
  }

  Future<void> setVolume(double value) async {
    final id = _playerId;
    volume = value.clamp(0.0, 1.0);
    isMuted = volume == 0;
    if (id == null) {
      notifyListeners();
      return;
    }
    await _platform.setVolume(id, isMuted ? 0 : volume);
    notifyListeners();
  }

  Future<void> setMuted(bool muted) async {
    isMuted = muted;
    final id = _playerId;
    if (id != null) {
      await _platform.setVolume(id, muted ? 0 : volume.clamp(0.0, 1.0));
    }
    notifyListeners();
  }

  Future<void> toggleMute() => setMuted(!isMuted);

  Future<void> setQuality(String quality) async {
    final id = _playerId;
    if (id == null) return;
    await _platform.setQuality(id, quality);
    currentQuality = quality;
    notifyListeners();
  }

  /// Opt-in PiP (Android Activity). Returns whether the OS entered PiP.
  Future<bool> enterPictureInPicture() async {
    final id = _playerId;
    if (id == null || !allowsPictureInPicture) return false;
    final ok = await _platform.enterPictureInPicture(id);
    isInPictureInPicture = ok;
    notifyListeners();
    return ok;
  }

  Future<bool> isPictureInPictureSupported() =>
      _platform.isPictureInPictureSupported();

  void setFullscreen(bool value) {
    if (isFullscreen == value) return;
    isFullscreen = value;
    notifyListeners();
  }

  Future<void> disposePlayer() async {
    _loadGeneration++;
    await _events?.cancel();
    _events = null;
    final id = _playerId;
    _playerId = null;
    textureId = null;
    isReady = false;
    isBuffering = false;
    isPlaying = false;
    isInPictureInPicture = false;
    _videoWidth = 0;
    _videoHeight = 0;
    if (id != null) {
      await _platform.disposePlayer(id);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(disposePlayer());
    super.dispose();
  }
}
