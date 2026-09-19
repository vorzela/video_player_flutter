import 'dart:async';

import 'package:flutter/material.dart';

import 'vorzela_fullscreen.dart';
import 'vorzela_player_controller.dart';
import 'vorzela_player_view.dart';

/// Ready-made player chrome (YouTube / Netflix / TikTok style).
///
/// - **Tap** → [tapAction] (default play/pause — not mute)
/// - **Fullscreen** button → [VorzelaFullscreen] with auto-rotate
/// - Mute / seek controls in the chrome bar
/// - Lifecycle pause is on [VorzelaPlayerController.pauseOnBackground]
class VorzelaPlayer extends StatefulWidget {
  const VorzelaPlayer({
    super.key,
    required this.controller,
    this.fit = BoxFit.contain,
    this.tapAction = VorzelaTapAction.playPause,
    this.showControls = true,
    this.autoRotateInFullscreen = true,
  });

  final VorzelaPlayerController controller;
  final BoxFit fit;
  final VorzelaTapAction tapAction;
  final bool showControls;
  final bool autoRotateInFullscreen;

  @override
  State<VorzelaPlayer> createState() => _VorzelaPlayerState();
}

class _VorzelaPlayerState extends State<VorzelaPlayer> {
  bool _showChrome = true;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _bumpChrome() {
    if (!widget.showControls) return;
    setState(() => _showChrome = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showChrome = false);
    });
  }

  Future<void> _handleTap() async {
    final c = widget.controller;
    switch (widget.tapAction) {
      case VorzelaTapAction.playPause:
        await c.togglePlayPause();
        _bumpChrome();
      case VorzelaTapAction.toggleMute:
        await c.toggleMute();
        _bumpChrome();
      case VorzelaTapAction.fullscreen:
        if (!c.isFullscreen && context.mounted) {
          await VorzelaFullscreen.open(
            context,
            controller: c,
            tapAction: VorzelaTapAction.playPause,
            autoRotate: widget.autoRotateInFullscreen,
          );
        }
      case VorzelaTapAction.none:
        _bumpChrome();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => unawaited(_handleTap()),
          child: Stack(
            fit: StackFit.expand,
            children: [
              VorzelaPlayerView(controller: c, fit: widget.fit),
              if (c.isBuffering)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white70),
                ),
              if (widget.showControls && _showChrome)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          IconButton(
                            color: Colors.white,
                            icon: Icon(
                              c.isPlaying ? Icons.pause : Icons.play_arrow,
                            ),
                            onPressed: () => unawaited(c.togglePlayPause()),
                          ),
                          IconButton(
                            color: Colors.white,
                            icon: Icon(
                              c.isMuted ? Icons.volume_off : Icons.volume_up,
                            ),
                            onPressed: () => unawaited(c.toggleMute()),
                          ),
                          Expanded(
                            child: Slider(
                              value: c.duration.inMilliseconds == 0
                                  ? 0
                                  : (c.position.inMilliseconds /
                                          c.duration.inMilliseconds)
                                      .clamp(0.0, 1.0),
                              onChanged: (v) {
                                final ms =
                                    (v * c.duration.inMilliseconds).round();
                                unawaited(
                                  c.seek(Duration(milliseconds: ms)),
                                );
                              },
                            ),
                          ),
                          IconButton(
                            color: Colors.white,
                            icon: const Icon(Icons.fullscreen),
                            onPressed: () {
                              unawaited(
                                VorzelaFullscreen.open(
                                  context,
                                  controller: c,
                                  autoRotate: widget.autoRotateInFullscreen,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
