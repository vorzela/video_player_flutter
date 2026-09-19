import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_flutter/video_player_flutter.dart';
import 'package:video_player_flutter_platform_interface/video_player_flutter_platform_interface.dart';

class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final events = StreamController<PlayerEvent>.broadcast();
  final disposed = <int>[];
  int nextId = 1;
  String? lastUri;
  String? lastQuality;
  Object? loadError;

  @override
  Future<int> create() async => nextId++;

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
  }) async {
    if (loadError != null) throw loadError!;
    lastUri = uri;
    events.add(PlayerReadyEvent(
      textureId: 42,
      durationMs: 10000,
      videoWidth: 1080,
      videoHeight: 1920,
      levels: const [
        QualityLevel(index: 0, height: 240, bitrate: 400000, label: '240p'),
        QualityLevel(index: 1, height: 720, bitrate: 2000000, label: '720p'),
      ],
    ));
  }

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> seek(int playerId, int positionMs) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setQuality(int playerId, String quality) async {
    lastQuality = quality;
  }

  @override
  Future<List<QualityLevel>> getLevels(int playerId) async => const [];

  @override
  Future<void> disposePlayer(int playerId) async {
    disposed.add(playerId);
  }

  @override
  Stream<PlayerEvent> eventsFor(int playerId) => events.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('controller load play dispose via fake platform', () async {
    final fake = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fake;
    final c = VorzelaPlayerController(platform: fake);

    await c.load('https://example.com/master.m3u8', autoPlay: true);
    await Future<void>.delayed(Duration.zero);
    expect(fake.lastUri, 'https://example.com/master.m3u8');
    expect(c.isReady, isTrue);
    expect(c.textureId, 42);
    expect(c.levels.length, 2);
    expect(c.isPlaying, isTrue);
    expect(c.videoWidth, 1080);
    expect(c.videoHeight, 1920);
    expect(c.videoAspectRatio, closeTo(1080 / 1920, 0.0001));

    await c.setQuality('480p');
    expect(fake.lastQuality, '480p');
    expect(c.currentQuality, '480p');

    await c.pause();
    expect(c.isPlaying, isFalse);

    await c.disposePlayer();
    expect(fake.disposed, isNotEmpty);
    c.dispose();
  });

  test('position and error events update controller', () async {
    final fake = FakeVideoPlayerPlatform();
    final c = VorzelaPlayerController(platform: fake);
    await c.load('https://example.com/a.m3u8');
    await Future<void>.delayed(Duration.zero);

    fake.events.add(const PlayerPositionEvent(positionMs: 1500, bufferedMs: 3000));
    await Future<void>.delayed(Duration.zero);
    expect(c.position.inMilliseconds, 1500);
    expect(c.buffered.inMilliseconds, 3000);

    fake.events.add(const PlayerErrorEvent('boom'));
    await Future<void>.delayed(Duration.zero);
    expect(c.error, 'boom');
    expect(c.isPlaying, isFalse);

    await c.disposePlayer();
    c.dispose();
  });

  test('load failure surfaces on error field', () async {
    final fake = FakeVideoPlayerPlatform();
    fake.loadError = PlatformException(
      code: 'insecure_uri',
      message: 'Only https:// URIs are allowed',
    );
    final c = VorzelaPlayerController(platform: fake);
    await c.load('http://example.com/a.m3u8');
    expect(c.error, contains('insecure_uri'));
    expect(c.isReady, isFalse);
    await c.disposePlayer();
    c.dispose();
  });
}
