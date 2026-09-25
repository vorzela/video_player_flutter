import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_flutter/video_player_flutter.dart';
import 'package:video_player_flutter_platform_interface/video_player_flutter_platform_interface.dart';

class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final events = StreamController<PlayerEvent>.broadcast();
  final disposed = <int>[];
  int nextId = 1;
  String? lastUri;

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
    lastUri = uri;
    events.add(PlayerReadyEvent(
      textureId: 42,
      durationMs: 10000,
      videoWidth: 640,
      videoHeight: 360,
      levels: const [],
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

  late FakeVideoPlayerPlatform fake;

  setUp(() {
    fake = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fake;
  });

  tearDown(() async {
    await fake.events.close();
  });

  test('auto-advances to next item on completed', () async {
    final playlist = VorzelaPlaylistController(platform: fake);
    addTearDown(playlist.dispose);

    await playlist.setQueue(const [
      VorzelaMediaItem(uri: 'https://example.com/1.m3u8'),
      VorzelaMediaItem(uri: 'https://example.com/2.m3u8'),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(playlist.currentIndex, 0);
    expect(fake.lastUri, 'https://example.com/1.m3u8');

    fake.events.add(const PlayerCompletedEvent());
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(playlist.currentIndex, 1);
    expect(fake.lastUri, 'https://example.com/2.m3u8');
  });

  test('next wraps with repeat all', () async {
    final playlist = VorzelaPlaylistController(platform: fake)
      ..repeatMode = VorzelaRepeatMode.all;
    addTearDown(playlist.dispose);

    await playlist.setQueue(const [
      VorzelaMediaItem(uri: 'https://example.com/a.m3u8'),
      VorzelaMediaItem(uri: 'https://example.com/b.m3u8'),
    ]);
    await Future<void>.delayed(Duration.zero);

    await playlist.playAt(1);
    await Future<void>.delayed(Duration.zero);
    expect(playlist.currentIndex, 1);

    await playlist.next();
    await Future<void>.delayed(Duration.zero);
    expect(playlist.currentIndex, 0);
    expect(fake.lastUri, 'https://example.com/a.m3u8');
  });

  test('only one native player disposed per track change', () async {
    final playlist = VorzelaPlaylistController(platform: fake);
    addTearDown(playlist.dispose);

    await playlist.setQueue(const [
      VorzelaMediaItem(uri: 'https://example.com/1.m3u8'),
      VorzelaMediaItem(uri: 'https://example.com/2.m3u8'),
    ]);
    await Future<void>.delayed(Duration.zero);
    final afterFirst = fake.disposed.length;

    await playlist.next();
    await Future<void>.delayed(Duration.zero);

    expect(fake.disposed.length, afterFirst + 1);
    expect(fake.disposed, isNotEmpty);
  });
}
