import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_flutter/video_player_flutter.dart';
import 'package:video_player_flutter_platform_interface/video_player_flutter_platform_interface.dart';

class _FakePlatform extends VideoPlayerPlatform {
  _FakePlatform(this.events);

  final StreamController<PlayerEvent> events;
  int? lastSeekMs;

  @override
  Future<int> create() async => 1;

  @override
  Future<void> disposePlayer(int playerId) async {}

  @override
  Stream<PlayerEvent> eventsFor(int playerId) => events.stream;

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
    events.add(const PlayerReadyEvent(
      textureId: 1,
      durationMs: 10000,
      videoWidth: 640,
      videoHeight: 360,
      levels: [],
    ));
  }

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> seek(int playerId, int positionMs) async {
    lastSeekMs = positionMs;
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setQuality(int playerId, String quality) async {}

  @override
  Future<List<QualityLevel>> getLevels(int playerId) async => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StreamController<PlayerEvent> eventBus;
  late _FakePlatform fake;
  late VorzelaPlayerController controller;

  setUp(() {
    eventBus = StreamController<PlayerEvent>.broadcast();
    fake = _FakePlatform(eventBus);
    VideoPlayerPlatform.instance = fake;
    controller = VorzelaPlayerController(platform: fake);
  });

  tearDown(() async {
    await controller.disposePlayer();
    controller.dispose();
    await eventBus.close();
  });

  test('vorzelaFormatTime renders mm:ss', () {
    expect(vorzelaFormatTime(const Duration(minutes: 2, seconds: 5)), '02:05');
    expect(vorzelaFormatTime(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03');
  });

  testWidgets('VorzelaPlayPauseButton exposes play semantics', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VorzelaPlayPauseButton(controller: controller),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Play'), findsOneWidget);
    await tester.tap(find.byType(VorzelaPlayPauseButton));
    await tester.pump();
  });

  testWidgets('VorzelaMuteButton exposes mute semantics', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VorzelaMuteButton(controller: controller),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Mute'), findsOneWidget);
  });

  testWidgets('VorzelaSeekBar builds when ready', (tester) async {
    await controller.load('https://example.com/a.m3u8');
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 48,
            child: VorzelaSeekBar(controller: controller),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(VorzelaSeekBar), findsOneWidget);
    // Seek without gesture (avoids Semantics increase/decrease flakiness).
    await controller.seek(const Duration(seconds: 3));
    expect(fake.lastSeekMs, 3000);
  });

  testWidgets('VorzelaProgressBar builds', (tester) async {
    await controller.load('https://example.com/a.m3u8');
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 8,
            child: VorzelaProgressBar(controller: controller),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(VorzelaProgressBar), findsOneWidget);
  });
}
