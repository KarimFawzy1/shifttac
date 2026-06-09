import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/tiki_game_state.dart';

/// Match HUD showing remaining hearts and elapsed timer.
class TikiTakaHud extends StatelessWidget {
  const TikiTakaHud({
    super.key,
    required this.hearts,
    required this.elapsedMs,
    this.maxHearts = TikiGameState.startingHearts,
  });

  final int hearts;
  final int elapsedMs;
  final int maxHearts;

  static String formatElapsed(int elapsedMs) {
    final duration = Duration(milliseconds: elapsedMs);
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (duration.inHours >= 1) {
      final hours = duration.inHours.toString().padLeft(2, '0');
      final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }

    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final timerLabel = formatElapsed(elapsedMs);

    return Row(
      children: [
        Semantics(
          label: 'Hearts: $hearts of $maxHearts',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < maxHearts; index++)
                Padding(
                  padding: EdgeInsets.only(right: 4.w),
                  child: Icon(
                    index < hearts ? Icons.favorite : Icons.favorite_border,
                    size: 22.sp,
                    color: index < hearts
                        ? AppColors.softCoral
                        : AppColors.outlineVariant,
                  ),
                ),
            ],
          ),
        ),
        const Spacer(),
        Semantics(
          label: 'Timer: $timerLabel',
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: AppSpacing.borderRadiusFull,
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              child: Text(
                timerLabel,
                style: AppTextStyles.labelBold.copyWith(
                  color: AppColors.onSurface,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
