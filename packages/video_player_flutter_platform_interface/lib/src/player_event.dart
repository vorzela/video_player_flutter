import 'quality_level.dart';

sealed class PlayerEvent {
  const PlayerEvent();
}

class PlayerReadyEvent extends PlayerEvent {
  const PlayerReadyEvent({
    required this.textureId,
    required this.durationMs,
    required this.levels,
  });

  final int textureId;
  final int durationMs;
  final List<QualityLevel> levels;
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
