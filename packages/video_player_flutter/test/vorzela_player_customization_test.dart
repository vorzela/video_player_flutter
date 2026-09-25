import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_flutter/video_player_flutter.dart';
import 'package:video_player_flutter_platform_interface/video_player_flutter_platform_interface.dart';

class _FakePlatform extends VideoPlayerPlatform {
  @override
  Future<int> create() async => 1;

  @override
  Future<void> disposePlayer(int playerId) async {}

  @override
  Stream<PlayerEvent> eventsFor(int playerId) => const Stream.empty();

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
  }) async {}

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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VorzelaPlayerController controller;

  setUp(() {
    VideoPlayerPlatform.instance = _FakePlatform();
    controller = VorzelaPlayerController(platform: VideoPlayerPlatform.instance);
  });

  tearDown(() async {
    await controller.disposePlayer();
    controller.dispose();
  });

  testWidgets('controlsBuilder replaces default chrome', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 180,
            child: VorzelaPlayer(
              controller: controller,
              controlsBuilder: (context, c, visible) =>
                  const Align(
                    alignment: Alignment.bottomCenter,
                    child: Text('CUSTOM_CONTROLS'),
                  ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('CUSTOM_CONTROLS'), findsOneWidget);
    expect(find.byIcon(Icons.fullscreen), findsNothing);
  });

  testWidgets('overlayBuilder is layered above video', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 180,
            child: VorzelaPlayer(
              controller: controller,
              showControls: false,
              overlayBuilder: (context, c) => const Text('OVERLAY'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('OVERLAY'), findsOneWidget);
  });

  testWidgets('player exposes semantics label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 180,
            child: VorzelaPlayer(
              controller: controller,
              showControls: false,
              semanticLabel: 'Featured clip',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.getSemantics(find.byType(VorzelaPlayer)),
      matchesSemantics(
        label: 'Featured clip',
        value: 'Paused',
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('hover posterBuilder customizes idle art', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 120,
            child: VorzelaHoverPreview(
              uri: 'https://example.com/preview.m3u8',
              poster: 'https://example.com/poster.jpg',
              startDelay: const Duration(hours: 1),
              posterBuilder: (context, url) => const Text('POSTER'),
            ),
          ),
        ),
      ),
    );
    expect(find.text('POSTER'), findsOneWidget);
  });
}