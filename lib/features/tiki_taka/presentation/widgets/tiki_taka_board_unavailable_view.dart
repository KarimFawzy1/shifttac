import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/primary_button.dart';

/// Shown when no playable board could be loaded from the local database.
class TikiTakaBoardUnavailableView extends StatelessWidget {
  const TikiTakaBoardUnavailableView({
    super.key,
    required this.onRetry,
  });

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.containerPadding.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.grid_off_rounded,
              size: 40.sp,
              color: AppColors.onSurfaceVariant,
            ),
            SizedBox(height: AppSpacing.stackMd.h),
            Text(
              'No board available',
              textAlign: TextAlign.center,
              style: AppTextStyles.titleXs.copyWith(color: AppColors.inkNavy),
            ),
            SizedBox(height: AppSpacing.stackSm.h),
            Text(
              'We could not load a Tiki-Taka board from local data.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            SizedBox(height: AppSpacing.stackMd.h),
            PrimaryButton(label: 'Try again', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
