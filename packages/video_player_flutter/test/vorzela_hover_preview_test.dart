import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_flutter/video_player_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
              startDelay: Duration(hours: 1), // never auto-start in test
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(VorzelaPlayerView), findsNothing);
  });
}
