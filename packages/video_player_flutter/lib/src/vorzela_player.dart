import 'dart:async';

import 'package:flutter/material.dart';

import 'vorzela_fullscreen.dart';
import 'vorzela_player_controller.dart';
import 'vorzela_player_style.dart';
import 'vorzela_player_view.dart';

/// Ready-made player chrome (YouTube / Netflix / TikTok style).
///
/// Customize look via builders; package still owns [VorzelaPlayerController]
/// and the Texture surface ([VorzelaPlayerView]).
///
/// Escape hatch for fully custom UI:
/// ```dart
/// Stack(children: [
///   VorzelaPlayerView(controller: c),
///   MyChrome(controller: c),
/// ])
/// ```
class VorzelaPlayer extends StatefulWidget {
  const VorzelaPlayer({
    super.key,
    required this.controller,
    this.fit = BoxFit.contain,
    this.tapAction = VorzelaTapAction.playPause,
    this.showControls = true,
    this.autoRotateInFullscreen = true,
    this.chromeHideAfter = const Duration(seconds: 3),
    this.onTap,
    this.controlsBuilder,
    this.overlayBuilder,
    this.bufferingBuilder,
    this.posterBuilder,
    this.style = const VorzelaPlayerStyle(),
    this.semanticLabel = 'Video player',
  });

  final VorzelaPlayerController controller;
  final BoxFit fit;
  final VorzelaTapAction tapAction;
  final bool showControls;
  final bool autoRotateInFullscreen;
  final Duration chromeHideAfter;

  /// Called after the default [tapAction] (or instead when [tapAction] is none).
  final VoidCallback? onTap;

  final VorzelaControlsBuilder? controlsBuilder;
  final VorzelaOverlayBuilder? overlayBuilder;
  final VorzelaBufferingBuilder? bufferingBuilder;
  final VorzelaPosterBuilder? posterBuilder;
  final VorzelaPlayerStyle style;
  final String semanticLabel;

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
    _hideTimer = Timer(widget.chromeHideAfter, () {
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
            controlsBuilder: widget.controlsBuilder,
            overlayBuilder: widget.overlayBuilder,
            bufferingBuilder: widget.bufferingBuilder,
            posterBuilder: widget.posterBuilder,
            style: widget.style,
          );
        }
      case VorzelaTapAction.none:
        _bumpChrome();
    }
    widget.onTap?.call();
  }

  Widget _defaultBuffering() {
    return Center(
      child: Semantics(
        label: 'Buffering',
        liveRegion: true,
        child: CircularProgressIndicator(color: widget.style.bufferingColor),
      ),
    );
  }

  Widget _defaultControls(VorzelaPlayerController c) {
    final style = widget.style;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: style.chromeGradient),
        child: SafeArea(
          top: false,
          child: MergeSemantics(
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: c.isPlaying ? 'Pause' : 'Play',
                  child: IconButton(
                    color: style.iconColor,
                    iconSize: style.iconSize,
                    icon: Icon(
                      c.isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                    onPressed: () => unawaited(c.togglePlayPause()),
                  ),
                ),
                Semantics(
                  button: true,
                  label: c.isMuted ? 'Unmute' : 'Mute',
                  child: IconButton(
                    color: style.iconColor,
                    iconSize: style.iconSize,
                    icon: Icon(
                      c.isMuted ? Icons.volume_off : Icons.volume_up,
                    ),
                    onPressed: () => unawaited(c.toggleMute()),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    slider: true,
                    label: 'Seek',
                    value:
                        '${c.position.inSeconds} of ${c.duration.inSeconds} seconds',
                    child: Slider(
                      activeColor: style.progressActiveColor,
                      inactiveColor: style.progressInactiveColor,
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
                ),
                Semantics(
                  button: true,
                  label: 'Fullscreen',
                  child: IconButton(
                    color: style.iconColor,
                    iconSize: style.iconSize,
                    icon: const Icon(Icons.fullscreen),
                    onPressed: () {
                      unawaited(
                        VorzelaFullscreen.open(
                          context,
                          controller: c,
                          autoRotate: widget.autoRotateInFullscreen,
                          controlsBuilder: widget.controlsBuilder,
                          overlayBuilder: widget.overlayBuilder,
                          bufferingBuilder: widget.bufferingBuilder,
                          posterBuilder: widget.posterBuilder,
                          style: widget.style,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final status = c.error != null
            ? 'Error'
            : c.isBuffering
                ? 'Buffering'
                : c.isPlaying
                    ? 'Playing'
                    : 'Paused';
        return Semantics(
          container: true,
          label: widget.semanticLabel,
          value: status,
          liveRegion: c.isBuffering || c.error != null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => unawaited(_handleTap()),
            child: Stack(
              fit: StackFit.expand,
              children: [
                VorzelaPlayerView(
                  controller: c,
                  fit: widget.fit,
                  posterBuilder: widget.posterBuilder,
                ),
                if (c.isBuffering)
                  widget.bufferingBuilder?.call(context) ??
                      _defaultBuffering(),
                if (widget.overlayBuilder != null)
                  widget.overlayBuilder!(context, c),
                if (widget.showControls && _showChrome)
                  widget.controlsBuilder?.call(context, c, _showChrome) ??
                      _defaultControls(c),
              ],
            ),
          ),
        );
      },
    );
  }
}
