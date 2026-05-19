import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/image_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Light panel shell for rules content (fill + border, no elevation).
class _HowToPlayPanel extends StatelessWidget {
  const _HowToPlayPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.stackMd.w),
        child: child,
      ),
    );
  }
}

/// One rules section: board-first visual, then title and copy (`design.md` §HOW TO PLAY).
class HowToPlayStep extends StatelessWidget {
  const HowToPlayStep({
    super.key,
    this.stepNumber,
    required this.title,
    required this.description,
    required this.visual,
    this.semanticLabel,
  });

  final int? stepNumber;
  final String title;
  final String description;
  final Widget visual;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final label =
        semanticLabel ??
        (stepNumber != null
            ? 'Step $stepNumber of $title. $description'
            : '$title. $description');

    return Semantics(
      container: true,
      label: label,
      child: _HowToPlayPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: visual),
            SizedBox(height: AppSpacing.stackMd.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (stepNumber != null) ...[
                  _StepBadge(number: stepNumber!),
                  SizedBox(width: AppSpacing.stackMd.w),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.headlineSm.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.unit.h),
            Text(
              description,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Strategy callout after core rules (accent panel, image-inspired layout).
class HowToPlayTip extends StatelessWidget {
  const HowToPlayTip({
    super.key,
    this.headline = 'Predict the shift.\nMemory wins games.',
    this.subtitle = 'No ties. The board always evolves.',
  });

  final String headline;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final semanticsLabel = 'Tip. $headline $subtitle';

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.primaryContainer.withValues(alpha: 0.12),
          borderRadius: AppSpacing.borderRadiusMd,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: ClipRRect(
          borderRadius: AppSpacing.borderRadiusMd,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: 10.w,
                top: 8.h,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.14,
                    child: SvgPicture.asset(
                      IconConstant.target,
                      width: 100.r,
                      height: 100.r,
                      colorFilter: const ColorFilter.mode(
                        AppColors.primary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(AppSpacing.stackMd.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _TipBadge(),
                    SizedBox(height: AppSpacing.stackMd.h),
                    Text(
                      headline,
                      style: AppTextStyles.headlineSm.copyWith(
                        color: AppColors.inkNavy,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    SizedBox(height: AppSpacing.stackSm.h),
                    Container(
                      width: 48.w,
                      height: 3.h,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: AppSpacing.borderRadiusFull,
                      ),
                    ),
                    SizedBox(height: AppSpacing.stackSm.h),
                    Text(
                      subtitle,
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
      ),
    );
  }
}

class _TipBadge extends StatelessWidget {
  const _TipBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceMist.withValues(alpha: 0.65),
        borderRadius: AppSpacing.borderRadiusFull,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.unit.w,
          AppSpacing.unit.h,
          AppSpacing.stackSm.w,
          AppSpacing.unit.h,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(5.r),
                child: Icon(
                  Icons.lightbulb,
                  size: 14.r,
                  color: AppColors.onPrimary,
                ),
              ),
            ),
            SizedBox(width: AppSpacing.stackSm.w),
            Text(
              'TIP',
              style: AppTextStyles.labelBold.copyWith(
                color: AppColors.primary,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.2),
        borderRadius: AppSpacing.borderRadiusMd,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.stackSm.w,
          vertical: AppSpacing.unit.h,
        ),
        child: Text(
          '$number',
          style: AppTextStyles.labelBold.copyWith(color: AppColors.primary),
        ),
      ),
    );
  }
}
