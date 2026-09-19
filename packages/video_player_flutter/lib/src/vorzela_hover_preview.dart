import 'dart:async';

import 'package:flutter/material.dart';

import 'vorzela_player_controller.dart';
import 'vorzela_player_view.dart';

/// Thumbnail that plays a short muted preview on hover (Netflix-style),
/// and falls back to a poster otherwise.
///
/// **Platforms:** this package ships **Android + iOS only** (no web/desktop
/// native engine). Use another player on web. Hover still works on
/// iPad/Android tablets with a mouse/trackpad; touch-only devices use
/// long-press.
///
/// Prefer a short, low-bitrate preview HLS clip for [uri] — not the full
/// master. Each active preview owns a real ExoPlayer/AVPlayer; [exclusive]
/// (default) ensures only one preview plays at a time in a grid.
class VorzelaHoverPreview extends StatefulWidget {
  const VorzelaHoverPreview({
    super.key,
    required this.uri,
    required this.poster,
    this.previewDuration = const Duration(seconds: 5),
    this.startDelay = const Duration(milliseconds: 350),
    this.fit = BoxFit.cover,
    this.loop = true,
    this.exclusive = true,
  });

  /// HLS URL to preview (ideally a dedicated short clip).
  final String uri;
  final String poster;

  /// How much of [uri] to show before looping (or pausing if [loop] is false).
  final Duration previewDuration;

  /// Debounce so a fast mouse sweep across a row does not spin up players.
  final Duration startDelay;

  final BoxFit fit;

  /// Loop the first [previewDuration] while hovered/held.
  final bool loop;

  /// If true, starting this preview stops any other exclusive preview.
  final bool exclusive;

  @override
  State<VorzelaHoverPreview> createState() => _VorzelaHoverPreviewState();
}

class _VorzelaHoverPreviewState extends State<VorzelaHoverPreview> {
  static _VorzelaHoverPreviewState? _exclusiveOwner;

  VorzelaPlayerController? _controller;
  Timer? _startTimer;
  Timer? _loopTimer;
  bool _active = false;
  int _generation = 0;

  void _onEnter() {
    _startTimer?.cancel();
    _startTimer = Timer(widget.startDelay, () {
      unawaited(_startPreview());
    });
  }

  void _onExit() {
    _startTimer?.cancel();
    unawaited(_stopPreview());
  }

  Future<void> _startPreview() async {
    if (!mounted || _active) return;
    final gen = ++_generation;

    if (widget.exclusive) {
      final prev = _exclusiveOwner;
      if (prev != null && prev != this) {
        await prev._stopPreview();
      }
      _exclusiveOwner = this;
    }

    final controller = VorzelaPlayerController();
    try {
      await controller.load(widget.uri, autoPlay: true, fastStart: true);
      await controller.setVolume(0);
    } catch (_) {
      await controller.disposePlayer();
      controller.dispose();
      return;
    }

    if (!mounted || gen != _generation) {
      await controller.disposePlayer();
      controller.dispose();
      return;
    }

    setState(() {
      _controller = controller;
      _active = true;
    });
    _scheduleLoopOrStop();
  }

  void _scheduleLoopOrStop() {
    _loopTimer?.cancel();
    _loopTimer = Timer(widget.previewDuration, () async {
      final controller = _controller;
      if (controller == null || !_active || !mounted) return;
      if (widget.loop) {
        await controller.seek(Duration.zero);
        if (_active && mounted) _scheduleLoopOrStop();
      } else {
        await controller.pause();
      }
    });
  }

  Future<void> _stopPreview() async {
    _generation++;
    _startTimer?.cancel();
    _loopTimer?.cancel();
    if (_exclusiveOwner == this) _exclusiveOwner = null;

    final controller = _controller;
    _controller = null;
    _active = false;
    if (mounted) setState(() {});

    if (controller != null) {
      await controller.disposePlayer();
      controller.dispose();
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _loopTimer?.cancel();
    if (_exclusiveOwner == this) _exclusiveOwner = null;
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      unawaited(() async {
        await controller.disposePlayer();
        controller.dispose();
      }());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onEnter(),
      onExit: (_) => _onExit(),
      child: GestureDetector(
        onLongPressStart: (_) => unawaited(_startPreview()),
        onLongPressEnd: (_) => unawaited(_stopPreview()),
        child: _active && _controller != null
            ? VorzelaPlayerView(controller: _controller!, fit: widget.fit)
            : Image.network(
                widget.poster,
                fit: widget.fit,
                errorBuilder: (context, error, stackTrace) =>
                    const ColoredBox(color: Colors.black),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : const ColoredBox(color: Colors.black),
              ),
      ),
    );
  }
}
