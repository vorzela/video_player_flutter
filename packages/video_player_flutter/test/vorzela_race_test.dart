import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_flutter/video_player_flutter.dart';
import 'package:video_player_flutter_platform_interface/video_player_flutter_platform_interface.dart';

class SlowVideoFake extends VideoPlayerPlatform {
  SlowVideoFake({this.loadDelay = Duration.zero});

  final Duration loadDelay;
  final events = StreamController<PlayerEvent>.broadcast();
  final disposed = <int>[];
  final created = <int>[];
  int nextId = 1;
  String? lastUri;

  @override
  Future<int> create() async {
    final id = nextId++;
    created.add(id);
    return id;
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
  }) async {
    await Future<void>.delayed(loadDelay);
    lastUri = uri;
    events.add(PlayerReadyEvent(
      textureId: playerId,
      durationMs: 5000,
      videoWidth: 640,
      videoHeight: 360,
      levels: const [
        QualityLevel(index: 0, height: 240, bitrate: 400000, label: '240p'),
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
  Future<void> setQuality(int playerId, String quality) async {}

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

  late SlowVideoFake fake;

  setUp(() {
    fake = SlowVideoFake();
    VideoPlayerPlatform.instance = fake;
  });

  tearDown(() async {
    await VorzelaPreviewSession.instance.disposeNow();
    await fake.events.close();
  });

  test('overlapping video loads dispose stale native ids', () async {
    fake = SlowVideoFake(loadDelay: const Duration(milliseconds: 40));
    VideoPlayerPlatform.instance = fake;
    final c = VorzelaPlayerController(platform: fake);

    final a = c.load('https://example.com/a.m3u8');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final b = c.load('https://example.com/b.m3u8');
    await Future.wait([a, b]);
    await Future<void>.delayed(Duration.zero);

    expect(fake.lastUri, 'https://example.com/b.m3u8');
    expect(fake.created.length - fake.disposed.length, lessThanOrEqualTo(1));

    await c.disposePlayer();
    c.dispose();
  });

  test('playlist completed vs next races to single advance', () async {
    final playlist = VorzelaPlaylistController(platform: fake);
    addTearDown(playlist.dispose);

    await playlist.setQueue(const [
      VorzelaMediaItem(uri: 'https://example.com/1.m3u8'),
      VorzelaMediaItem(uri: 'https://example.com/2.m3u8'),
      VorzelaMediaItem(uri: 'https://example.com/3.m3u8'),
    ]);
    await Future<void>.delayed(Duration.zero);

    fake.events.add(const PlayerCompletedEvent());
    unawaited(playlist.next());
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(playlist.currentIndex, 1);
    expect(fake.lastUri, 'https://example.com/2.m3u8');
  });

  test('preview session acquire/release racing yields one owner', () async {
    fake = SlowVideoFake(loadDelay: const Duration(milliseconds: 25));
    VideoPlayerPlatform.instance = fake;
    final session = VorzelaPreviewSession.instance;
    await session.disposeNow();

    final ownerA = Object();
    final ownerB = Object();

    final acquireA = session.acquire(
      owner: ownerA,
      uri: 'https://example.com/a.m3u8',
      volume: 0,
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    session.release(ownerA);
    final acquireB = session.acquire(
      owner: ownerB,
      uri: 'https://example.com/b.m3u8',
      volume: 0,
    );

    final resultB = await acquireB;
    final resultA = await acquireA;

    expect(resultA, isNull);
    expect(resultB, isNotNull);
    expect(session.owner, ownerB);

    session.release(ownerB);
    await session.disposeNow();
  });

  test('preview release then immediate disposeNow is safe', () async {
    final session = VorzelaPreviewSession.instance;
    await session.disposeNow();
    final owner = Object();
    unawaited(session.acquire(
      owner: owner,
      uri: 'https://example.com/p.m3u8',
      volume: 0,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    session.release(owner);
    await session.disposeNow();
    expect(session.controller, isNull);
  });
}
