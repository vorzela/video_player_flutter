import 'package:flutter/material.dart';

import 'vorzela_player_controller.dart';

/// Texture-backed player view (not a PlatformView — lower memory).
class VorzelaPlayerView extends StatelessWidget {
  const VorzelaPlayerView({
    super.key,
    required this.controller,
    this.fit = BoxFit.contain,
  });

  final VorzelaPlayerController controller;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final textureId = controller.textureId;
        if (textureId == null) {
          if (controller.poster != null) {
            return Image.network(controller.poster!, fit: fit);
          }
          return const ColoredBox(color: Colors.black);
        }
        return FittedBox(
          fit: fit,
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width,
            height: MediaQuery.sizeOf(context).width * 9 / 16,
            child: Texture(textureId: textureId),
          ),
        );
      },
    );
  }
}
