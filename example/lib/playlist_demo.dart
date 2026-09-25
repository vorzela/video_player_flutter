import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player_flutter/video_player_flutter.dart';

/// Minimal playlist screen using [VorzelaPlaylistController].
class PlaylistDemoPage extends StatefulWidget {
  const PlaylistDemoPage({super.key});

  @override
  State<PlaylistDemoPage> createState() => _PlaylistDemoPageState();
}

class _PlaylistDemoPageState extends State<PlaylistDemoPage> {
  late final VorzelaPlaylistController playlist;

  @override
  void initState() {
    super.initState();
    playlist = VorzelaPlaylistController()..repeatMode = VorzelaRepeatMode.all;
    unawaited(
      playlist.setQueue(const [
        VorzelaMediaItem(
          uri: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
          title: 'Mux test stream',
        ),
        VorzelaMediaItem(
          uri: 'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8',
          title: 'Apple bipbop sample',
        ),
      ]),
    );
  }

  @override
  void dispose() {
    playlist.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Playlist')),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: playlist.player.videoAspectRatio ?? 16 / 9,
            child: VorzelaPlayer(controller: playlist.player),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous),
                onPressed: () => unawaited(playlist.previous()),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next),
                onPressed: () => unawaited(playlist.next()),
              ),
            ],
          ),
          Expanded(
            child: VorzelaPlaylistView(
              controller: playlist,
              itemBuilder: (context, item, index, isCurrent) => ListTile(
                title: Text(item.title ?? 'Track ${index + 1}'),
                subtitle: Text(item.uri, maxLines: 1, overflow: TextOverflow.ellipsis),
                selected: isCurrent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
