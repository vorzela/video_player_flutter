import 'quality_level.dart';

sealed class PlayerEvent {
  const PlayerEvent();
}

class PlayerReadyEvent extends PlayerEvent {
  const PlayerReadyEvent({
    required this.textureId,
    required this.durationMs,
    required this.levels,
    this.videoWidth = 0,
    this.videoHeight = 0,
  });

  final int textureId;
  final int durationMs;
  final List<QualityLevel> levels;

  /// Natural decoded frame size (`0` if not yet known). Used to size the
  /// texture at the video's real aspect ratio (portrait short-form included)
  /// instead of assuming 16:9.
  final int videoWidth;
  final int videoHeight;
}

class PlayerBufferingEvent extends PlayerEvent {
  const PlayerBufferingEvent(this.isBuffering);
  final bool isBuffering;
}

class PlayerPositionEvent extends PlayerEvent {
  const PlayerPositionEvent({
    required this.positionMs,
    required this.bufferedMs,
  });

  final int positionMs;
  final int bufferedMs;
}

class PlayerErrorEvent extends PlayerEvent {
  const PlayerErrorEvent(this.message);
  final String message;
}

class PlayerCompletedEvent extends PlayerEvent {
  const PlayerCompletedEvent();
}

/// Fired when the first non-blank decoded frame is on the texture.
/// UI should keep showing the poster until this arrives.
class PlayerFirstFrameEvent extends PlayerEvent {
  const PlayerFirstFrameEvent();
}
