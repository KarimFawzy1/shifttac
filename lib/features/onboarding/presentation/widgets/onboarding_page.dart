import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Single onboarding step: title, description, and a visual slot.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    required this.title,
    required this.description,
    required this.visual,
  });

  final String title;
  final String description;
  final Widget visual;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 48.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.containerPadding.w),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.displayLg.copyWith(color: AppColors.onSurface),
              ),
              SizedBox(height: AppSpacing.unit.h + 3),
              Text(
                description,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLg.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.stackLg.h),
        Expanded(
          child: Center(child: visual),
        ),
      ],
    );
  }
}

/// Page progress dots (active pill + inactive circles).
class OnboardingPageIndicator extends StatelessWidget {
  const OnboardingPageIndicator({
    super.key,
    required this.pageCount,
    required this.currentIndex,
  });

  final int pageCount;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (index) {
        final active = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          margin: EdgeInsets.symmetric(horizontal: AppSpacing.unit.w),
          width: active ? 32.w : 8.w,
          height: 8.h,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.outlineVariant,
            borderRadius: AppSpacing.borderRadiusFull,
          ),
        );
      }),
    );
  }
}
