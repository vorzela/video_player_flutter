import 'package:flutter/services.dart';

import 'player_event.dart';
import 'quality_level.dart';
import 'video_player_platform.dart';

class MethodChannelVideoPlayer extends VideoPlayerPlatform {
  MethodChannelVideoPlayer({
    MethodChannel? channel,
    EventChannel? events,
  })  : _channel = channel ?? const MethodChannel(kVorzelaPlayerChannel),
        _events = events ?? const EventChannel(kVorzelaPlayerEventsChannel);

  final MethodChannel _channel;
  final EventChannel _events;

  /// Flutter's [EventChannel] allows only **one** active native sink. Opening
  /// `receiveBroadcastStream` per player stomps previous listeners — fatal for
  /// feeds with multiple preloaded players. Share one native subscription and
  /// fan-out by `playerId` instead.
  static Stream<Map<Object?, Object?>>? _sharedRaw;
  static Stream<Map<Object?, Object?>> _rawEventStream(EventChannel events) {
    return _sharedRaw ??= events.receiveBroadcastStream().map((raw) {
      if (raw is Map) return Map<Object?, Object?>.from(raw);
      return <Object?, Object?>{};
    });
  }

  static void registerWith() {
    VideoPlayerPlatform.instance = MethodChannelVideoPlayer();
  }

  @override
  Future<int> create() async {
    final id = await _channel.invokeMethod<int>('create');
    return id ?? (throw StateError('create returned null'));
  }

  @override
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
    return _channel.invokeMethod<void>('load', {
      'playerId': playerId,
      'uri': uri,
      'poster': poster,
      'autoPlay': autoPlay,
      'fastStart': fastStart,
      'capToPlayerSize': capToPlayerSize,
      'viewWidth': viewWidth,
      'viewHeight': viewHeight,
    });
  }

  @override
  Future<void> play(int playerId) =>
      _channel.invokeMethod<void>('play', {'playerId': playerId});

  @override
  Future<void> pause(int playerId) =>
      _channel.invokeMethod<void>('pause', {'playerId': playerId});

  @override
  Future<void> seek(int playerId, int positionMs) => _channel.invokeMethod<void>(
        'seek',
        {'playerId': playerId, 'positionMs': positionMs},
      );

  @override
  Future<void> setVolume(int playerId, double volume) =>
      _channel.invokeMethod<void>('setVolume', {
        'playerId': playerId,
        'volume': volume,
      });

  @override
  Future<void> setQuality(int playerId, String quality) =>
      _channel.invokeMethod<void>('setQuality', {
        'playerId': playerId,
        'quality': quality,
      });

  @override
  Future<List<QualityLevel>> getLevels(int playerId) async {
    final raw = await _channel.invokeMethod<List<dynamic>>('getLevels', {
      'playerId': playerId,
    });
    return (raw ?? const [])
        .map((e) => QualityLevel.fromMap(Map<Object?, Object?>.from(e as Map)))
        .toList();
  }

  @override
  Future<void> disposePlayer(int playerId) =>
      _channel.invokeMethod<void>('dispose', {'playerId': playerId});

  @override
  Stream<PlayerEvent> eventsFor(int playerId) {
    return _rawEventStream(_events).where((e) {
      final id = e['playerId'];
      return id == playerId || (id is num && id.toInt() == playerId);
    }).map(_decodeEvent);
  }

  PlayerEvent _decodeEvent(Map<Object?, Object?> map) {
    final type = '${map['type']}';
    switch (type) {
      case 'ready':
        final levels = (map['levels'] as List? ?? const [])
            .map((e) => QualityLevel.fromMap(Map<Object?, Object?>.from(e as Map)))
            .toList();
        return PlayerReadyEvent(
          textureId: (map['textureId'] as num?)?.toInt() ?? 0,
          durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
          levels: levels,
          videoWidth: (map['videoWidth'] as num?)?.toInt() ?? 0,
          videoHeight: (map['videoHeight'] as num?)?.toInt() ?? 0,
        );
      case 'buffering':
        return PlayerBufferingEvent(map['isBuffering'] == true);
      case 'position':
        return PlayerPositionEvent(
          positionMs: (map['positionMs'] as num?)?.toInt() ?? 0,
          bufferedMs: (map['bufferedMs'] as num?)?.toInt() ?? 0,
        );
      case 'error':
        return PlayerErrorEvent('${map['message'] ?? 'unknown'}');
      case 'completed':
        return const PlayerCompletedEvent();
      default:
        return PlayerErrorEvent('Unknown event $type');
    }
  }
}
