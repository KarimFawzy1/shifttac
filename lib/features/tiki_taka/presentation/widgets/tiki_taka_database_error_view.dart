import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/local/tiki_taka_database.dart';

/// Controlled error surface when the bundled SQLite database cannot open.
class TikiTakaDatabaseErrorView extends StatelessWidget {
  const TikiTakaDatabaseErrorView({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  static String messageFor(Object error) {
    if (error is TikiTakaDatabaseException) {
      return switch (error.code) {
        TikiTakaDatabaseErrorCode.missingBundledAsset =>
          'Tiki-Taka data is missing from this install. Reinstall the app or contact support.',
        TikiTakaDatabaseErrorCode.invalidBundledDatabase =>
          'Tiki-Taka data looks corrupted. Try again or reinstall the app.',
        TikiTakaDatabaseErrorCode.copyFailed =>
          'Could not prepare Tiki-Taka data on this device. Free storage and try again.',
        TikiTakaDatabaseErrorCode.openFailed =>
          'Could not open Tiki-Taka data. Try again or reinstall the app.',
      };
    }

    return 'Could not load Tiki-Taka data. Check storage and try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.containerPadding.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.storage_rounded,
                size: 48.sp,
                color: AppColors.onSurfaceVariant,
              ),
              SizedBox(height: AppSpacing.stackMd.h),
              Text(
                'Tiki-Taka unavailable',
                textAlign: TextAlign.center,
                style: AppTextStyles.titleSm.copyWith(color: AppColors.inkNavy),
              ),
              SizedBox(height: AppSpacing.stackSm.h),
              Text(
                messageFor(error),
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              SizedBox(height: AppSpacing.stackLg.h),
              PrimaryButton(label: 'Try again', onPressed: onRetry),
            ],
          ),
        ),
      ),
    );
  }
}
