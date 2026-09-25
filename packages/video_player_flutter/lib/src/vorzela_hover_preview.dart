import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vorzela_image/vorzela_image.dart';

import 'vorzela_player_controller.dart';
import 'vorzela_player_style.dart';
import 'vorzela_player_view.dart';
import 'vorzela_preview_session.dart';

/// State passed to [VorzelaHoverPreview.overlayBuilder].
@immutable
class VorzelaHoverPreviewState {
  const VorzelaHoverPreviewState({
    required this.playing,
    required this.muted,
    this.controller,
  });

  final bool playing;
  final bool muted;
  final VorzelaPlayerController? controller;
}

/// Low-memory thumbnail preview on hover / long-press (YouTube / Netflix style).
///
/// - **Android + iOS only** (no web — use another player there).
/// - Shares **one** native player via [VorzelaPreviewSession] (not one per tile).
/// - Customize poster/overlay via builders; never create per-tile controllers.
class VorzelaHoverPreview extends StatefulWidget {
  const VorzelaHoverPreview({
    super.key,
    required this.uri,
    this.poster,
    this.posterBuilder,
    this.overlayBuilder,
    this.frameBuilder,
    this.previewDuration = const Duration(seconds: 5),
    this.startDelay = const Duration(milliseconds: 280),
    this.fit = BoxFit.cover,
    this.loop = true,
    this.muted = true,
    this.volume = 1.0,
    this.maxDecodeHeight = 360,
    this.lowQuality = true,
    this.tapTogglesMute = true,
    this.enableDefaultGestures = true,
    this.onMuteChanged,
    this.onHoverStart,
    this.onHoverEnd,
    this.onTap,
    this.semanticLabel = 'Video preview',
  }) : assert(
          poster != null || posterBuilder != null,
          'Provide poster URL and/or posterBuilder',
        );

  /// Prefer a short, low-bitrate preview HLS — not the full feature master.
  final String uri;

  /// Poster URL when [posterBuilder] is null.
  final String? poster;

  final VorzelaPosterBuilder? posterBuilder;

  /// Mute badge, title, etc. Return [SizedBox.shrink] to hide default badge.
  final Widget Function(BuildContext context, VorzelaHoverPreviewState state)?
      overlayBuilder;

  /// Wrap texture+poster (radius, border, hero).
  final Widget Function(BuildContext context, Widget child)? frameBuilder;

  final Duration previewDuration;
  final Duration startDelay;
  final BoxFit fit;
  final bool loop;

  /// Start muted (default). YouTube-style; unmute via tap if [tapTogglesMute].
  final bool muted;

  /// Volume when unmuted (`0.0`–`1.0`).
  final double volume;

  /// Max video height hint for ABR / peak bitrate (keeps RAM low).
  final int maxDecodeHeight;

  /// Pin to the lowest available quality ladder rung for the preview.
  final bool lowQuality;

  /// Tap while previewing toggles mute (YouTube hover card behavior).
  final bool tapTogglesMute;

  /// When false, host wires hover/tap; package still owns the session.
  final bool enableDefaultGestures;

  final ValueChanged<bool>? onMuteChanged;
  final VoidCallback? onHoverStart;
  final VoidCallback? onHoverEnd;
  final VoidCallback? onTap;
  final String semanticLabel;

  @override
  State<VorzelaHoverPreview> createState() => _VorzelaHoverPreviewState();
}

class _VorzelaHoverPreviewState extends State<VorzelaHoverPreview> {
  final _session = VorzelaPreviewSession.instance;

  Timer? _startTimer;
  Timer? _loopTimer;
  bool _active = false;
  bool _muted = true;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _muted = widget.muted;
  }

  @override
  void didUpdateWidget(covariant VorzelaHoverPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.muted != widget.muted && !_active) {
      _muted = widget.muted;
    }
  }

  double get _effectiveVolume => _muted ? 0.0 : widget.volume;

  void _onEnter() {
    widget.onHoverStart?.call();
    if (!widget.enableDefaultGestures) return;
    _startTimer?.cancel();
    _startTimer = Timer(widget.startDelay, () => unawaited(_start()));
  }

  void _onExit() {
    widget.onHoverEnd?.call();
    if (!widget.enableDefaultGestures) return;
    _startTimer?.cancel();
    _stop();
  }

  Future<void> _start() async {
    if (!mounted || _active) return;
    final gen = ++_gen;

    final c = await _session.acquire(
      owner: this,
      uri: widget.uri,
      volume: _effectiveVolume,
      maxHeight: widget.maxDecodeHeight,
      lowQuality: widget.lowQuality,
    );

    if (!mounted || gen != _gen || c == null) {
      if (_session.owner == this) _session.release(this);
      return;
    }

    setState(() => _active = true);
    _armLoop();
  }

  void _armLoop() {
    _loopTimer?.cancel();
    _loopTimer = Timer(widget.previewDuration, () async {
      if (!_active || !mounted || _session.owner != this) return;
      if (widget.loop) {
        await _session.seekZero();
        if (_active && mounted) _armLoop();
      } else {
        await _session.pause();
      }
    });
  }

  void _stop() {
    _gen++;
    _startTimer?.cancel();
    _loopTimer?.cancel();
    final wasActive = _active;
    _active = false;
    _session.release(this);
    if (wasActive && mounted) setState(() {});
  }

  Future<void> _toggleMute() async {
    if (!_active || !widget.tapTogglesMute) return;
    setState(() => _muted = !_muted);
    widget.onMuteChanged?.call(_muted);
    await _session.setVolume(_effectiveVolume);
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _loopTimer?.cancel();
    _session.release(this);
    super.dispose();
  }

  Widget _buildPoster(BuildContext context) {
    if (widget.posterBuilder != null) {
      return widget.posterBuilder!(context, widget.poster);
    }
    return VorzelaImage.network(
      widget.poster!,
      fit: widget.fit,
      maxHeight: widget.maxDecodeHeight.toDouble(),
      semanticLabel: 'Preview poster',
      errorBuilder: (context, error, stackTrace) =>
          const ColoredBox(color: Colors.black),
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : const ColoredBox(color: Colors.black),
    );
  }

  Widget _defaultOverlay(VorzelaHoverPreviewState state) {
    if (!state.playing || !widget.tapTogglesMute) {
      return const SizedBox.shrink();
    }
    return Positioned(
      right: 6,
      bottom: 6,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                state.muted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playing = _active &&
        _session.owner == this &&
        _session.controller != null &&
        _session.controller!.textureId != null;

    final state = VorzelaHoverPreviewState(
      playing: playing,
      muted: _muted,
      controller: playing ? _session.controller : null,
    );

    Widget child = Stack(
      fit: StackFit.expand,
      children: [
        if (playing)
          VorzelaPlayerView(
            controller: _session.controller!,
            fit: widget.fit,
            // Keep real poster until first non-blank frame (not a black flash).
            posterBuilder: (context, _) => _buildPoster(context),
          )
        else
          _buildPoster(context),
        if (widget.overlayBuilder != null)
          widget.overlayBuilder!(context, state)
        else
          _defaultOverlay(state),
      ],
    );

    if (widget.frameBuilder != null) {
      child = widget.frameBuilder!(context, child);
    }

    child = Semantics(
      label: widget.semanticLabel,
      button: widget.tapTogglesMute,
      child: child,
    );

    if (!widget.enableDefaultGestures) {
      return GestureDetector(
        onTap: widget.onTap,
        child: child,
      );
    }

    return MouseRegion(
      onEnter: (_) => _onEnter(),
      onExit: (_) => _onExit(),
      child: GestureDetector(
        onLongPressStart: (_) => unawaited(_start()),
        onLongPressEnd: (_) => _stop(),
        onTap: playing
            ? () {
                widget.onTap?.call();
                unawaited(_toggleMute());
              }
            : widget.onTap,
        child: child,
      ),
    );
  }
}
