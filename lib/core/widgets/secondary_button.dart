import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onPressed == null
          ? null
          : () {
              Feedback.forTap(context);
              onPressed!();
            },
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.surfaceContainerLowest,
        disabledBackgroundColor: AppColors.surfaceContainerLow,
        foregroundColor: AppColors.primary,
        disabledForegroundColor: AppColors.onSurfaceVariant,
        side: const BorderSide(color: AppColors.outlineVariant),
        minimumSize: Size.fromHeight(
          AppSpacing.stackLg.h + AppSpacing.stackMd.h,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.containerPadding.w,
          vertical: AppSpacing.stackMd.h,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusLg),
        textStyle: AppTextStyles.labelBold,
      ),
      child: _ButtonContent(label: label, leading: leading),
    );

    if (!expand) {
      return button;
    }

    return SizedBox(width: double.infinity, child: button);
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({required this.label, this.leading});

  final String label;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    if (leading == null) {
      return Text(label);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        leading!,
        SizedBox(width: AppSpacing.stackSm.w),
        Text(label),
      ],
    );
  }
}
