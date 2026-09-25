import 'package:flutter/material.dart';

import 'vorzela_player_controller.dart';

/// Optional colors / sizes for default [VorzelaPlayer] chrome (no full rebuild).
@immutable
class VorzelaPlayerStyle {
  const VorzelaPlayerStyle({
    this.iconColor = Colors.white,
    this.inactiveIconColor = Colors.white70,
    this.progressActiveColor,
    this.progressInactiveColor = Colors.white24,
    this.bufferingColor = Colors.white70,
    this.chromeGradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Colors.black54],
    ),
    this.iconSize = 24,
  });

  final Color iconColor;
  final Color inactiveIconColor;
  final Color? progressActiveColor;
  final Color progressInactiveColor;
  final Color bufferingColor;
  final Gradient chromeGradient;
  final double iconSize;

  VorzelaPlayerStyle copyWith({
    Color? iconColor,
    Color? inactiveIconColor,
    Color? progressActiveColor,
    Color? progressInactiveColor,
    Color? bufferingColor,
    Gradient? chromeGradient,
    double? iconSize,
  }) {
    return VorzelaPlayerStyle(
      iconColor: iconColor ?? this.iconColor,
      inactiveIconColor: inactiveIconColor ?? this.inactiveIconColor,
      progressActiveColor: progressActiveColor ?? this.progressActiveColor,
      progressInactiveColor:
          progressInactiveColor ?? this.progressInactiveColor,
      bufferingColor: bufferingColor ?? this.bufferingColor,
      chromeGradient: chromeGradient ?? this.chromeGradient,
      iconSize: iconSize ?? this.iconSize,
    );
  }
}

/// Entire bottom bar / side actions — replaces default mute/seek/fullscreen row.
typedef VorzelaControlsBuilder = Widget Function(
  BuildContext context,
  VorzelaPlayerController controller,
  bool chromeVisible,
);

/// Titles, live badge, ads slot, watermark.
typedef VorzelaOverlayBuilder = Widget Function(
  BuildContext context,
  VorzelaPlayerController controller,
);

/// Replace default [CircularProgressIndicator].
typedef VorzelaBufferingBuilder = Widget Function(BuildContext context);

/// Before ready / error art.
typedef VorzelaPosterBuilder = Widget Function(
  BuildContext context,
  String? posterUrl,
);
