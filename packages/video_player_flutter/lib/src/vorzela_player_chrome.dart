import 'dart:async';

import 'package:flutter/material.dart';

import 'vorzela_player_controller.dart';
import 'vorzela_player_style.dart';

/// Formats [duration] as `mm:ss` (or `h:mm:ss` when longer than an hour).
String vorzelaFormatTime(Duration duration) {
  final negative = duration.isNegative;
  final d = negative ? -duration : duration;
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60);
  final body = hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
      : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  return negative ? '-$body' : body;
}

/// Non-interactive played + buffered progress strip.
class VorzelaProgressBar extends StatelessWidget {
  const VorzelaProgressBar({
    super.key,
    required this.controller,
    this.activeColor,
    this.inactiveColor,
    this.bufferedColor,
    this.height = 4,
  });

  final VorzelaPlayerController controller;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? bufferedColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final active = activeColor ?? theme.colorScheme.primary;
        final inactive = inactiveColor ?? theme.colorScheme.surfaceContainerHighest;
        final buffered = bufferedColor ?? active.withValues(alpha: 0.35);
        final durationMs = controller.duration.inMilliseconds;
        final played = durationMs == 0
            ? 0.0
            : controller.position.inMilliseconds / durationMs;
        final buf = durationMs == 0
            ? 0.0
            : controller.buffered.inMilliseconds / durationMs;
        return _ProgressTrack(
          height: height,
          played: played.clamp(0.0, 1.0),
          buffered: buf.clamp(0.0, 1.0),
          activeColor: active,
          inactiveColor: inactive,
          bufferedColor: buffered,
        );
      },
    );
  }
}

/// Drag-to-seek bar with buffered trail; calls [VorzelaPlayerController.seek].
class VorzelaSeekBar extends StatefulWidget {
  const VorzelaSeekBar({
    super.key,
    required this.controller,
    this.activeColor,
    this.inactiveColor,
    this.bufferedColor,
    this.height = 24,
    this.trackHeight = 4,
  });

  final VorzelaPlayerController controller;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? bufferedColor;
  final double height;
  final double trackHeight;

  @override
  State<VorzelaSeekBar> createState() => _VorzelaSeekBarState();
}

class _VorzelaSeekBarState extends State<VorzelaSeekBar> {
  double? _dragValue;

  double _fraction(VorzelaPlayerController c) {
    if (_dragValue != null) return _dragValue!.clamp(0.0, 1.0);
    final ms = c.duration.inMilliseconds;
    if (ms == 0) return 0;
    return (c.position.inMilliseconds / ms).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final theme = Theme.of(context);
        final active = widget.activeColor ?? theme.colorScheme.primary;
        final inactive =
            widget.inactiveColor ?? theme.colorScheme.surfaceContainerHighest;
        final buffered = widget.bufferedColor ?? active.withValues(alpha: 0.35);
        final durationMs = c.duration.inMilliseconds;
        final played = _fraction(c);
        final buf = durationMs == 0
            ? 0.0
            : (c.buffered.inMilliseconds / durationMs).clamp(0.0, 1.0);

        final valueLabel = durationMs == 0
            ? '0 of 0 seconds'
            : '${c.position.inSeconds} of ${c.duration.inSeconds} seconds';
        final step = durationMs == 0 ? 0 : (durationMs * 0.05).round();
        final increased = durationMs == 0
            ? null
            : '${(c.position.inMilliseconds + step).clamp(0, durationMs) ~/ 1000} of ${c.duration.inSeconds} seconds';
        final decreased = durationMs == 0
            ? null
            : '${(c.position.inMilliseconds - step).clamp(0, durationMs) ~/ 1000} of ${c.duration.inSeconds} seconds';

        return Semantics(
          slider: true,
          label: 'Seek',
          value: valueLabel,
          increasedValue: increased,
          decreasedValue: decreased,
          onIncrease: durationMs == 0
              ? null
              : () {
                  unawaited(c.seek(c.position + Duration(milliseconds: step)));
                },
          onDecrease: durationMs == 0
              ? null
              : () {
                  unawaited(c.seek(c.position - Duration(milliseconds: step)));
                },
          child: SizedBox(
            height: widget.height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: durationMs == 0
                      ? null
                      : (_) => setState(() => _dragValue = played),
                  onHorizontalDragUpdate: durationMs == 0
                      ? null
                      : (details) {
                          setState(() {
                            _dragValue =
                                (details.localPosition.dx / w).clamp(0.0, 1.0);
                          });
                        },
                  onHorizontalDragEnd: durationMs == 0
                      ? null
                      : (_) {
                          final v = _dragValue ?? played;
                          setState(() => _dragValue = null);
                          unawaited(
                            c.seek(
                              Duration(milliseconds: (v * durationMs).round()),
                            ),
                          );
                        },
                  onTapDown: durationMs == 0
                      ? null
                      : (details) {
                          final v =
                              (details.localPosition.dx / w).clamp(0.0, 1.0);
                          unawaited(
                            c.seek(
                              Duration(milliseconds: (v * durationMs).round()),
                            ),
                          );
                        },
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      _ProgressTrack(
                        height: widget.trackHeight,
                        played: played,
                        buffered: buf,
                        activeColor: active,
                        inactiveColor: inactive,
                        bufferedColor: buffered,
                      ),
                      if (durationMs > 0)
                        Positioned(
                          left: (w * played).clamp(0.0, w) - 6,
                          child: Material(
                            elevation: 1,
                            color: active,
                            shape: const CircleBorder(),
                            child: const SizedBox(width: 12, height: 12),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({
    required this.height,
    required this.played,
    required this.buffered,
    required this.activeColor,
    required this.inactiveColor,
    required this.bufferedColor,
  });

  final double height;
  final double played;
  final double buffered;
  final Color activeColor;
  final Color inactiveColor;
  final Color bufferedColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.centerLeft,
          children: [
            ColoredBox(color: inactiveColor),
            FractionallySizedBox(
              widthFactor: buffered,
              alignment: Alignment.centerLeft,
              child: ColoredBox(color: bufferedColor),
            ),
            FractionallySizedBox(
              widthFactor: played,
              alignment: Alignment.centerLeft,
              child: ColoredBox(color: activeColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// Current position or duration as `mm:ss`.
class VorzelaTimeLabel extends StatelessWidget {
  const VorzelaTimeLabel({
    super.key,
    required this.duration,
    this.style,
  });

  final Duration duration;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      vorzelaFormatTime(duration),
      style: style,
    );
  }
}

/// Play / pause control wired to [VorzelaPlayerController].
class VorzelaPlayPauseButton extends StatelessWidget {
  const VorzelaPlayPauseButton({
    super.key,
    required this.controller,
    this.style = const VorzelaPlayerStyle(),
  });

  final VorzelaPlayerController controller;
  final VorzelaPlayerStyle style;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Semantics(
          button: true,
          label: controller.isPlaying ? 'Pause' : 'Play',
          excludeSemantics: true,
          child: IconButton(
            color: style.iconColor,
            iconSize: style.iconSize,
            icon: Icon(
              controller.isPlaying ? Icons.pause : Icons.play_arrow,
            ),
            onPressed: () => unawaited(controller.togglePlayPause()),
          ),
        );
      },
    );
  }
}

/// Mute / unmute control wired to [VorzelaPlayerController].
class VorzelaMuteButton extends StatelessWidget {
  const VorzelaMuteButton({
    super.key,
    required this.controller,
    this.style = const VorzelaPlayerStyle(),
  });

  final VorzelaPlayerController controller;
  final VorzelaPlayerStyle style;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Semantics(
          button: true,
          label: controller.isMuted ? 'Unmute' : 'Mute',
          excludeSemantics: true,
          child: IconButton(
            color: style.iconColor,
            iconSize: style.iconSize,
            icon: Icon(
              controller.isMuted ? Icons.volume_off : Icons.volume_up,
            ),
            onPressed: () => unawaited(controller.toggleMute()),
          ),
        );
      },
    );
  }
}
