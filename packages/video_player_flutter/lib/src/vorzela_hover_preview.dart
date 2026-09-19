import 'dart:async';

import 'package:flutter/material.dart';

import 'vorzela_player_view.dart';
import 'vorzela_preview_session.dart';

/// Low-memory thumbnail preview on hover / long-press (YouTube / Netflix style).
///
/// - **Android + iOS only** (no web — use another player there).
/// - Shares **one** native player via [VorzelaPreviewSession] (not one per tile).
/// - Default **muted** (browser/OS autoplay rules + less surprising UX); set
///   [muted] false or tap the preview to unmute.
/// - Caps decode height ([maxDecodeHeight]) and locks to the lowest HLS rung
///   so a hover never pulls full 1080p into RAM.
/// - On exit: pause immediately, dispose native player after a short idle.
class VorzelaHoverPreview extends StatefulWidget {
  const VorzelaHoverPreview({
    super.key,
    required this.uri,
    required this.poster,
    this.previewDuration = const Duration(seconds: 5),
    this.startDelay = const Duration(milliseconds: 280),
    this.fit = BoxFit.cover,
    this.loop = true,
    this.muted = true,
    this.volume = 1.0,
    this.maxDecodeHeight = 360,
    this.lowQuality = true,
    this.tapTogglesMute = true,
    this.onMuteChanged,
  });

  /// Prefer a short, low-bitrate preview HLS — not the full feature master.
  final String uri;
  final String poster;

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

  final ValueChanged<bool>? onMuteChanged;

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
    _startTimer?.cancel();
    _startTimer = Timer(widget.startDelay, () => unawaited(_start()));
  }

  void _onExit() {
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

  @override
  Widget build(BuildContext context) {
    final playing = _active &&
        _session.owner == this &&
        _session.controller != null &&
        _session.controller!.textureId != null;

    return MouseRegion(
      onEnter: (_) => _onEnter(),
      onExit: (_) => _onExit(),
      child: GestureDetector(
        onLongPressStart: (_) => unawaited(_start()),
        onLongPressEnd: (_) => _stop(),
        onTap: playing ? () => unawaited(_toggleMute()) : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (playing)
              VorzelaPlayerView(
                controller: _session.controller!,
                fit: widget.fit,
              )
            else
              Image.network(
                widget.poster,
                fit: widget.fit,
                errorBuilder: (context, error, stackTrace) =>
                    const ColoredBox(color: Colors.black),
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const ColoredBox(color: Colors.black),
              ),
            if (playing && widget.tapTogglesMute)
              Positioned(
                right: 6,
                bottom: 6,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        _muted ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
