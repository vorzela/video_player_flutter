import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_flutter/video_player_flutter.dart';
import 'package:vorzela_image/vorzela_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await VorzelaPreviewSession.instance.disposeNow();
  });

  testWidgets('VorzelaHoverPreview shows poster until hover starts',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 120,
            child: VorzelaHoverPreview(
              uri: 'https://example.com/preview.m3u8',
              poster: 'https://example.com/poster.jpg',
              startDelay: Duration(hours: 1),
              muted: true,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(VorzelaImage), findsOneWidget);
    expect(find.byType(VorzelaPlayerView), findsNothing);
    expect(VorzelaPreviewSession.instance.isBusy, isFalse);
  });

  test('preview session is a singleton', () {
    expect(
      identical(
        VorzelaPreviewSession.instance,
        VorzelaPreviewSession.instance,
      ),
      isTrue,
    );
  });
}
