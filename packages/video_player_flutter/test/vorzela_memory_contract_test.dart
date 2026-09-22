import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_flutter/video_player_flutter.dart';
import 'package:video_player_flutter_platform_interface/video_player_flutter_platform_interface.dart';

/// Fake platform that tracks create/dispose for memory-contract tests.
class TrackingFakePlatform extends VideoPlayerPlatform {
  final events = StreamController<PlayerEvent>.broadcast();
  final created = <int>[];
  final disposed = <int>[];
  int nextId = 1;

  String? lastUri;
  String? lastQuality;
  int? lastViewWidth;
  int? lastViewHeight;
  bool? lastCapToPlayerSize;
  bool? lastFastStart;

  int get activeCount => created.length - disposed.length;

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
    lastUri = uri;
    lastViewWidth = viewWidth;
    lastViewHeight = viewHeight;
    lastCapToPlayerSize = capToPlayerSize;
    lastFastStart = fastStart;
    events.add(PlayerReadyEvent(
      textureId: 100 + playerId,
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

  late TrackingFakePlatform fake;

  setUp(() {
    fake = TrackingFakePlatform();
    VideoPlayerPlatform.instance = fake;
  });

  tearDown(() async {
    await VorzelaPreviewSession.instance.disposeNow();
    await fake.events.close();
  });

  test('reload disposes previous native player (no stack)', () async {
    final c = VorzelaPlayerController(platform: fake);
    await c.load('https://cdn.example.com/a.m3u8');
    await Future<void>.delayed(Duration.zero);
    final first = fake.created.single;
    expect(fake.activeCount, 1);

    await c.load('https://cdn.example.com/b.m3u8');
    await Future<void>.delayed(Duration.zero);
    expect(fake.disposed, contains(first));
    expect(fake.created.length, 2);
    expect(fake.activeCount, 1);

    await c.disposePlayer();
    expect(fake.activeCount, 0);
    c.dispose();
  });

  test('disposePlayer tears down native id', () async {
    final c = VorzelaPlayerController(platform: fake);
    await c.load('https://cdn.example.com/a.m3u8');
    await Future<void>.delayed(Duration.zero);
    expect(fake.activeCount, 1);
    await c.disposePlayer();
    expect(fake.activeCount, 0);
    expect(fake.disposed, isNotEmpty);
    c.dispose();
  });

  test('preview acquire caps decode size and stays on lowest quality', () async {
    final owner = Object();
    await VorzelaPreviewSession.instance.acquire(
      owner: owner,
      uri: 'https://cdn.example.com/preview.m3u8',
      volume: 0,
      maxHeight: 360,
      lowQuality: true,
    );
    expect(fake.lastViewWidth, 640);
    expect(fake.lastViewHeight, 360);
    expect(fake.lastCapToPlayerSize, isTrue);
    expect(fake.lastFastStart, isTrue);
    expect(fake.lastQuality, '240p');
    expect(fake.activeCount, 1);

    VorzelaPreviewSession.instance.release(owner);
    await VorzelaPreviewSession.instance.disposeNow();
    expect(fake.activeCount, 0);
  });

  test('shared preview session never stacks two active players', () async {
    final a = Object();
    final b = Object();
    await VorzelaPreviewSession.instance.acquire(
      owner: a,
      uri: 'https://cdn.example.com/a.m3u8',
      volume: 0,
    );
    await VorzelaPreviewSession.instance.acquire(
      owner: b,
      uri: 'https://cdn.example.com/b.m3u8',
      volume: 0,
    );
    // One shared controller: create once, second load disposes previous id.
    expect(fake.activeCount, lessThanOrEqualTo(1));
    VorzelaPreviewSession.instance.release(b);
    await VorzelaPreviewSession.instance.disposeNow();
    expect(fake.activeCount, 0);
  });

  test('idle release disposes native player after idleDisposeDelay', () async {
    final owner = Object();
    await VorzelaPreviewSession.instance.acquire(
      owner: owner,
      uri: 'https://cdn.example.com/preview.m3u8',
      volume: 0,
    );
    expect(fake.activeCount, 1);
    VorzelaPreviewSession.instance.release(owner);

    await Future<void>.delayed(
      VorzelaPreviewSession.idleDisposeDelay + const Duration(milliseconds: 80),
    );
    expect(VorzelaPreviewSession.instance.controller, isNull);
    expect(fake.activeCount, 0);
  });

  test('re-acquire before idle cancels dispose', () async {
    final a = Object();
    final b = Object();
    await VorzelaPreviewSession.instance.acquire(
      owner: a,
      uri: 'https://cdn.example.com/a.m3u8',
      volume: 0,
    );
    VorzelaPreviewSession.instance.release(a);
    await VorzelaPreviewSession.instance.acquire(
      owner: b,
      uri: 'https://cdn.example.com/b.m3u8',
      volume: 0,
    );
    await Future<void>.delayed(
      VorzelaPreviewSession.idleDisposeDelay + const Duration(milliseconds: 80),
    );
    expect(VorzelaPreviewSession.instance.isBusy, isTrue);
    expect(fake.activeCount, 1);

    VorzelaPreviewSession.instance.release(b);
    await VorzelaPreviewSession.instance.disposeNow();
    expect(fake.activeCount, 0);
  });

  test('README memory knobs stay documented in platform constants', () {
    // Contract: Dart throttle constant matches native 250ms tick (README).
    expect(kPositionEventThrottleMs, 250);
    expect(VorzelaPreviewSession.idleDisposeDelay.inMilliseconds, 800);
  });
}
