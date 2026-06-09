import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Full-screen blurred scrim for modal overlays (pause menu, win dialog, etc.).
class ModalBackdrop extends StatelessWidget {
  const ModalBackdrop({
    super.key,
    required this.progress,
    this.onTap,
    this.maxBlurSigma = 4,
    this.scrimAlpha = 0.2,
    this.enableBlur = true,
  });

  /// Animation progress from 0 (none) to 1 (full blur/scrim).
  final double progress;
  final VoidCallback? onTap;
  final double maxBlurSigma;
  final double scrimAlpha;

  /// When false, only the scrim is drawn. Useful during route transitions
  /// so the first [BackdropFilter] compile does not hitch the animation.
  final bool enableBlur;

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0);
    final scrim = ColoredBox(
      color: AppColors.inkNavy.withValues(alpha: scrimAlpha * t),
    );
    final backdrop = enableBlur && t > 0
        ? ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: maxBlurSigma * t,
                sigmaY: maxBlurSigma * t,
              ),
              child: scrim,
            ),
          )
        : scrim;

    if (onTap == null) {
      return backdrop;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: backdrop,
    );
  }
}
