import 'package:flutter/material.dart';
import 'package:vorzela_image/vorzela_image.dart';

import 'vorzela_player_controller.dart';
import 'vorzela_player_style.dart';

/// Texture-backed player view (not a PlatformView — lower memory).
///
/// Sizes the texture from [VorzelaPlayerController.videoAspectRatio] (real
/// decoded width/height). No hardcoded 16:9 — works for portrait short-form,
/// landscape, and square. Until dimensions are known, fills the parent.
class VorzelaPlayerView extends StatelessWidget {
  const VorzelaPlayerView({
    super.key,
    required this.controller,
    this.fit = BoxFit.contain,
    this.posterBuilder,
  });

  final VorzelaPlayerController controller;
  final BoxFit fit;
  final VorzelaPosterBuilder? posterBuilder;

  Widget _defaultPoster(BuildContext context, String? url) {
    if (url == null) return const ColoredBox(color: Colors.black);
    return VorzelaImage.network(
      url,
      fit: fit,
      semanticLabel: 'Video poster',
      errorBuilder: (context, error, stackTrace) =>
          const ColoredBox(color: Colors.black),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const ColoredBox(color: Colors.black),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final textureId = controller.textureId;
        // Keep poster until a real (non-blank) frame is on the texture.
        final showVideo = textureId != null && controller.hasFirstFrame;
        if (!showVideo) {
          final url = controller.poster;
          if (posterBuilder != null) {
            return posterBuilder!(context, url);
          }
          return _defaultPoster(context, url);
        }

        return Semantics(
          excludeSemantics: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final ar = controller.videoAspectRatio;
              final maxW = constraints.maxWidth;
              final maxH = constraints.maxHeight;
              final hasW =
                  constraints.hasBoundedWidth && maxW.isFinite && maxW > 0;
              final hasH =
                  constraints.hasBoundedHeight && maxH.isFinite && maxH > 0;

              late final double width;
              late final double height;
              if (ar != null && ar > 0) {
                if (hasW && hasH) {
                  if (maxW / maxH > ar) {
                    height = maxH;
                    width = maxH * ar;
                  } else {
                    width = maxW;
                    height = maxW / ar;
                  }
                } else if (hasW) {
                  width = maxW;
                  height = maxW / ar;
                } else if (hasH) {
                  height = maxH;
                  width = maxH * ar;
                } else {
                  width = 16;
                  height = 16 / ar;
                }
              } else {
                width = hasW ? maxW : (hasH ? maxH : 16);
                height = hasH ? maxH : (hasW ? maxW : 16);
              }

              return ClipRect(
                child: FittedBox(
                  fit: fit,
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: Texture(textureId: textureId),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
