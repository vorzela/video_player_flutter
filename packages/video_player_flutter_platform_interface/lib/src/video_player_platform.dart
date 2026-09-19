import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'player_event.dart';
import 'quality_level.dart';

/// Channel name prefix (Pigeon / MethodChannel).
const String kVorzelaPlayerChannel = 'com.vorzela.video_player_flutter/player';
const String kVorzelaPlayerEventsChannel =
    'com.vorzela.video_player_flutter/events';

/// Minimum gap between position events (ms) — keeps Dart isolate light.
const int kPositionEventThrottleMs = 250;

abstract class VideoPlayerPlatform extends PlatformInterface {
  VideoPlayerPlatform() : super(token: _token);

  static final Object _token = Object();
  static VideoPlayerPlatform _instance = _UnimplementedVideoPlayerPlatform();

  static VideoPlayerPlatform get instance => _instance;

  static set instance(VideoPlayerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<int> create() {
    throw UnimplementedError('create() has not been implemented.');
  }

  Future<void> load(
    int playerId, {
    required String uri,
    String? poster,
    bool autoPlay = false,
    bool fastStart = true,
    bool capToPlayerSize = true,
    int? viewWidth,
    int? viewHeight,
  }) {
    throw UnimplementedError('load() has not been implemented.');
  }

  Future<void> play(int playerId) {
    throw UnimplementedError('play() has not been implemented.');
  }

  Future<void> pause(int playerId) {
    throw UnimplementedError('pause() has not been implemented.');
  }

  Future<void> seek(int playerId, int positionMs) {
    throw UnimplementedError('seek() has not been implemented.');
  }

  Future<void> setVolume(int playerId, double volume) {
    throw UnimplementedError('setVolume() has not been implemented.');
  }

  Future<void> setQuality(int playerId, String quality) {
    throw UnimplementedError('setQuality() has not been implemented.');
  }

  Future<List<QualityLevel>> getLevels(int playerId) {
    throw UnimplementedError('getLevels() has not been implemented.');
  }

  Future<void> disposePlayer(int playerId) {
    throw UnimplementedError('disposePlayer() has not been implemented.');
  }

  /// Opt-in: enter Android Activity PiP (keeps playback when leaving the app).
  /// Default unsupported → returns `false`. Not required for normal playback.
  Future<bool> enterPictureInPicture(int playerId) async => false;

  Future<bool> isPictureInPictureSupported() async => false;

  Stream<PlayerEvent> eventsFor(int playerId) {
    throw UnimplementedError('eventsFor() has not been implemented.');
  }
}

class _UnimplementedVideoPlayerPlatform extends VideoPlayerPlatform {}
