import 'package:flutter/widgets.dart';
import 'package:video_player_flutter/video_player_flutter.dart';

class GoodPlayerState extends State<GoodPlayerStateful> {
  late final VorzelaPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = VorzelaPlayerController();
    controller.load('https://example.com/stream.m3u8');
  }

  @override
  Widget build(BuildContext context) {
    return VorzelaPlayer(controller: controller);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class GoodPlayerStateful extends StatefulWidget {
  const GoodPlayerStateful({super.key});

  @override
  State<GoodPlayerStateful> createState() => GoodPlayerState();
}

class GoodListPage extends StatelessWidget {
  const GoodListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const VorzelaHoverPreview(
      uri: 'https://example.com/preview.m3u8',
      poster: 'https://example.com/preview.jpg',
    );
  }
}
