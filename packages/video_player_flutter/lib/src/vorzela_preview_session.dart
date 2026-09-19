import 'dart:async';

import 'vorzela_player_controller.dart';

/// Process-wide **one** preview ExoPlayer/AVPlayer — YouTube/TikTok style.
///
/// Hover grids and feed tiles must not each allocate a native player. All
/// [VorzelaHoverPreview] (and similar) callers share this session: at most one
/// preview plays; idle players are disposed after [idleDisposeDelay] so RAM
/// drops back to zero when nothing is hovered.
final class VorzelaPreviewSession {
  VorzelaPreviewSession._();
  static final VorzelaPreviewSession instance = VorzelaPreviewSession._();

  /// How long after the last release before the native player is torn down.
  static const Duration idleDisposeDelay = Duration(milliseconds: 800);

  VorzelaPlayerController? _controller;
  Object? _owner;
  Timer? _idleTimer;
  int _epoch = 0;

  VorzelaPlayerController? get controller => _controller;
  Object? get owner => _owner;
  bool get isBusy => _owner != null;

  /// Claim the shared player for [owner]. Stops any previous owner.
  Future<VorzelaPlayerController?> acquire({
    required Object owner,
    required String uri,
    required double volume,
    int? maxHeight,
    bool lowQuality = true,
  }) async {
    _idleTimer?.cancel();
    final epoch = ++_epoch;

    // Kick previous owner out (they should release on notify, but we own the
    // controller regardless).
    _owner = owner;

    final c = _controller ??= VorzelaPlayerController();
    // Cap decode size — preview tiles are small; don't pull 1080p into RAM.
    final h = maxHeight ?? 360;
    final w = (h * 16 / 9).round();

    await c.load(
      uri,
      autoPlay: true,
      fastStart: true,
      capToPlayerSize: true,
      viewWidth: w,
      viewHeight: h,
    );
    if (epoch != _epoch || _owner != owner) return null;

    // `load` returns before the ready event — wait briefly so levels exist.
    for (var i = 0; i < 100 && !c.isReady; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (epoch != _epoch || _owner != owner) return null;
    }

    await c.setVolume(volume.clamp(0.0, 1.0));
    if (lowQuality && c.levels.isNotEmpty) {
      // Stay on the cheapest rung for the whole preview (no ABR climb).
      await c.setQuality(c.levels.first.label);
    }
    if (epoch != _epoch || _owner != owner) return null;
    return c;
  }

  /// Apply volume without reloading (mute / unmute while hovering).
  Future<void> setVolume(double volume) async {
    final c = _controller;
    if (c == null) return;
    await c.setVolume(volume.clamp(0.0, 1.0));
  }

  Future<void> seekZero() async {
    final c = _controller;
    if (c == null) return;
    await c.seek(Duration.zero);
    if (!c.isPlaying) await c.play();
  }

  Future<void> pause() async {
    await _controller?.pause();
  }

  /// Release ownership. Schedules full native dispose if nobody re-acquires.
  void release(Object owner) {
    if (_owner != owner) return;
    _owner = null;
    _epoch++;
    unawaited(_controller?.pause());
    _idleTimer?.cancel();
    _idleTimer = Timer(idleDisposeDelay, () {
      if (_owner != null) return;
      final c = _controller;
      _controller = null;
      if (c != null) {
        unawaited(() async {
          await c.disposePlayer();
          c.dispose();
        }());
      }
    });
  }

  /// Immediate teardown (tests / app background).
  Future<void> disposeNow() async {
    _idleTimer?.cancel();
    _owner = null;
    _epoch++;
    final c = _controller;
    _controller = null;
    if (c != null) {
      await c.disposePlayer();
      c.dispose();
    }
  }
}
