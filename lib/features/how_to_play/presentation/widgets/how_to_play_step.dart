import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

/// One rules step: number badge, mini visual, title, and short caption.
class HowToPlayStep extends StatelessWidget {
  const HowToPlayStep({
    super.key,
    required this.stepNumber,
    required this.title,
    required this.caption,
    required this.visual,
    this.centerTitle = false,
    this.visualSize,
  });

  final int stepNumber;
  final String title;
  final String caption;
  final Widget visual;
  final bool centerTitle;
  final double? visualSize;

  @override
  Widget build(BuildContext context) {
    final frameSize = visualSize ?? 128.w;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withValues(alpha: 0.6),
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(
          color: AppColors.surfaceContainerLowest.withValues(alpha: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.inkNavy.withValues(alpha: 0.05),
            offset: Offset(0, 4.h),
            blurRadius: 12.r,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.stackMd.w),
        child: Column(
          children: [
            SizedBox(
              width: frameSize,
              height: frameSize,
              child: visual,
            ),
            SizedBox(height: AppSpacing.stackMd.h),
            Align(
              alignment:
                  centerTitle ? Alignment.center : Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: centerTitle
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    'STEP $stepNumber',
                    style: AppTextStyles.labelBold.copyWith(
                      color: AppColors.primary,
                      letterSpacing: 0.7,
                    ),
                  ),
                  SizedBox(height: AppSpacing.unit.h),
                  Text(
                    title,
                    textAlign: centerTitle ? TextAlign.center : TextAlign.start,
                    style: AppTextStyles.headlineSm,
                  ),
                  SizedBox(height: AppSpacing.stackSm.h - 1),
                  Text(
                    caption,
                    textAlign: centerTitle ? TextAlign.center : TextAlign.start,
                    maxLines: 2,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mint preview frame used by step visuals (`css/HowtoPlayScreen.css`).
class HowToPlayVisualFrame extends StatelessWidget {
  const HowToPlayVisualFrame({
    super.key,
    required this.child,
    this.size,
  });

  final Widget child;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final side = size ?? 128.w;

    return SizedBox(
      width: side,
      height: side,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceMist,
          borderRadius: AppSpacing.borderRadiusDefault,
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Center(child: child),
      ),
    );
  }
}
