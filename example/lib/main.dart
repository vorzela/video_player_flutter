import 'package:flutter/material.dart';
import 'package:video_player_flutter/video_player_flutter.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  // pauseOnBackground: true (default). allowsPictureInPicture: false (opt-in).
  final controller = VorzelaPlayerController(
    pauseOnBackground: true,
    allowsPictureInPicture: false,
  );
  final urlController = TextEditingController(
    text: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
  );

  @override
  void dispose() {
    controller.dispose();
    urlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await controller.load(
      urlController.text.trim(),
      fastStart: true,
      autoPlay: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Vorzela HLS')),
        body: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            return Column(
              children: [
                AspectRatio(
                  aspectRatio: controller.videoAspectRatio ?? 16 / 9,
                  child: VorzelaPlayer(
                    controller: controller,
                    tapAction: VorzelaTapAction.playPause,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'HLS master.m3u8 URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(onPressed: _load, child: const Text('Load')),
                    if (controller.isBuffering) const Text('Buffering…'),
                    if (controller.error != null)
                      Text(
                        controller.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
