import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'vorzela_player_controller.dart';
import 'vorzela_player_view.dart';

/// Opens an immersive fullscreen route with auto-rotate (YouTube / Netflix).
///
/// Restores UI + default orientations when popped. Tap uses [tapAction].
class VorzelaFullscreen {
  VorzelaFullscreen._();

  static Future<void> open(
    BuildContext context, {
    required VorzelaPlayerController controller,
    VorzelaTapAction tapAction = VorzelaTapAction.playPause,
    bool autoRotate = true,
  }) async {
    controller.setFullscreen(true);

    if (autoRotate) {
      // Device can rotate freely while fullscreen (YouTube-style).
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      final ar = controller.videoAspectRatio ?? 16 / 9;
      if (ar >= 1) {
        await SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        await SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      }
    }

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (context, animation, secondary) {
          return _FullscreenPage(
            controller: controller,
            tapAction: tapAction,
          );
        },
      ),
    );

    controller.setFullscreen(false);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Return to a sensible app default (portrait-primary); host can override.
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
  }
}

class _FullscreenPage extends StatefulWidget {
  const _FullscreenPage({
    required this.controller,
    required this.tapAction,
  });

  final VorzelaPlayerController controller;
  final VorzelaTapAction tapAction;

  @override
  State<_FullscreenPage> createState() => _FullscreenPageState();
}

class _FullscreenPageState extends State<_FullscreenPage> {
  bool _showChrome = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _bumpChrome();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _bumpChrome() {
    setState(() => _showChrome = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showChrome = false);
    });
  }

  Future<void> _onTap() async {
    switch (widget.tapAction) {
      case VorzelaTapAction.playPause:
        await widget.controller.togglePlayPause();
        _bumpChrome();
      case VorzelaTapAction.toggleMute:
        await widget.controller.toggleMute();
        _bumpChrome();
      case VorzelaTapAction.fullscreen:
        if (mounted) Navigator.of(context).pop();
      case VorzelaTapAction.none:
        _bumpChrome();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => unawaited(_onTap()),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: c.videoAspectRatio ?? 16 / 9,
                    child: VorzelaPlayerView(controller: c, fit: BoxFit.contain),
                  ),
                ),
                if (_showChrome) ...[
                  Positioned(
                    left: 8,
                    top: MediaQuery.paddingOf(context).top + 8,
                    child: IconButton(
                      color: Colors.white,
                      icon: const Icon(Icons.fullscreen_exit),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.paddingOf(context).bottom + 16,
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
                              unawaited(c.seek(Duration(milliseconds: ms)));
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
