import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'vorzela_player_controller.dart';
import 'vorzela_player_style.dart';
import 'vorzela_player_view.dart';

/// Opens an immersive fullscreen route with auto-rotate (YouTube / Netflix).
///
/// Restores UI + default orientations when popped. Tap uses [tapAction].
/// Builders mirror [VorzelaPlayer] so chrome stays consistent in fullscreen.
class VorzelaFullscreen {
  VorzelaFullscreen._();

  static Future<void> open(
    BuildContext context, {
    required VorzelaPlayerController controller,
    VorzelaTapAction tapAction = VorzelaTapAction.playPause,
    bool autoRotate = true,
    Duration chromeHideAfter = const Duration(seconds: 3),
    VorzelaControlsBuilder? controlsBuilder,
    VorzelaOverlayBuilder? overlayBuilder,
    VorzelaBufferingBuilder? bufferingBuilder,
    VorzelaPosterBuilder? posterBuilder,
    VorzelaPlayerStyle style = const VorzelaPlayerStyle(),
  }) async {
    controller.setFullscreen(true);

    if (autoRotate) {
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
            chromeHideAfter: chromeHideAfter,
            controlsBuilder: controlsBuilder,
            overlayBuilder: overlayBuilder,
            bufferingBuilder: bufferingBuilder,
            posterBuilder: posterBuilder,
            style: style,
          );
        },
      ),
    );

    controller.setFullscreen(false);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
  }
}

class _FullscreenPage extends StatefulWidget {
  const _FullscreenPage({
    required this.controller,
    required this.tapAction,
    required this.chromeHideAfter,
    this.controlsBuilder,
    this.overlayBuilder,
    this.bufferingBuilder,
    this.posterBuilder,
    this.style = const VorzelaPlayerStyle(),
  });

  final VorzelaPlayerController controller;
  final VorzelaTapAction tapAction;
  final Duration chromeHideAfter;
  final VorzelaControlsBuilder? controlsBuilder;
  final VorzelaOverlayBuilder? overlayBuilder;
  final VorzelaBufferingBuilder? bufferingBuilder;
  final VorzelaPosterBuilder? posterBuilder;
  final VorzelaPlayerStyle style;

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
    _hideTimer = Timer(widget.chromeHideAfter, () {
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

  Widget _defaultControls(VorzelaPlayerController c) {
    final style = widget.style;
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Stack(
      children: [
        Positioned(
          left: 8,
          top: topPad + 8,
          child: Semantics(
            button: true,
            label: 'Exit fullscreen',
            child: IconButton(
              color: style.iconColor,
              iconSize: style.iconSize,
              icon: const Icon(Icons.fullscreen_exit),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: bottomPad + 16,
          child: MergeSemantics(
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: c.isPlaying ? 'Pause' : 'Play',
                  child: IconButton(
                    color: style.iconColor,
                    iconSize: style.iconSize,
                    icon: Icon(c.isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: () => unawaited(c.togglePlayPause()),
                  ),
                ),
                Semantics(
                  button: true,
                  label: c.isMuted ? 'Unmute' : 'Mute',
                  child: IconButton(
                    color: style.iconColor,
                    iconSize: style.iconSize,
                    icon: Icon(c.isMuted ? Icons.volume_off : Icons.volume_up),
                    onPressed: () => unawaited(c.toggleMute()),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    slider: true,
                    label: 'Seek',
                    child: Slider(
                      activeColor: style.progressActiveColor,
                      inactiveColor: style.progressInactiveColor,
                      value: c.duration.inMilliseconds == 0
                          ? 0
                          : (c.position.inMilliseconds /
                                  c.duration.inMilliseconds)
                              .clamp(0.0, 1.0),
                      onChanged: (v) {
                        final ms = (v * c.duration.inMilliseconds).round();
                        unawaited(c.seek(Duration(milliseconds: ms)));
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          return Semantics(
            label: 'Fullscreen video player',
            value: c.isPlaying ? 'Playing' : 'Paused',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => unawaited(_onTap()),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio: c.videoAspectRatio ?? 16 / 9,
                      child: VorzelaPlayerView(
                        controller: c,
                        fit: BoxFit.contain,
                        posterBuilder: widget.posterBuilder,
                      ),
                    ),
                  ),
                  if (c.isBuffering)
                    widget.bufferingBuilder?.call(context) ??
                        Center(
                          child: Semantics(
                            label: 'Buffering',
                            liveRegion: true,
                            child: CircularProgressIndicator(
                              color: widget.style.bufferingColor,
                            ),
                          ),
                        ),
                  if (widget.overlayBuilder != null)
                    widget.overlayBuilder!(context, c),
                  if (_showChrome)
                    widget.controlsBuilder?.call(context, c, _showChrome) ??
                        _defaultControls(c),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
