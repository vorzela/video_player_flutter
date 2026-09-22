import 'package:flutter/widgets.dart';
import 'package:video_player_flutter/video_player_flutter.dart';

class BadPlayerPage extends StatelessWidget {
  const BadPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: avoid_vorzela_player_controller_in_build
    final c = VorzelaPlayerController();
    return VorzelaPlayer(controller: c);
  }
}

// expect_lint: prefer_dispose_vorzela_player_controller
class BadPlayerState extends State<BadPlayerStateful> {
  late final VorzelaPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = VorzelaPlayerController();
    // expect_lint: avoid_http_hls_load
    controller.load('http://example.com/stream.m3u8');
  }

  @override
  Widget build(BuildContext context) {
    return VorzelaPlayer(controller: controller);
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class BadPlayerStateful extends StatefulWidget {
  const BadPlayerStateful({super.key});

  @override
  State<BadPlayerStateful> createState() => BadPlayerState();
}

class BadListPage extends StatelessWidget {
  const BadListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (context, index) {
        // expect_lint: avoid_hover_preview_per_list_item
        return VorzelaHoverPreview(
          uri: 'https://example.com/$index.m3u8',
          poster: 'https://example.com/$index.jpg',
        );
      },
    );
  }
}
