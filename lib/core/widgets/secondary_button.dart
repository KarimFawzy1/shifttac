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
        ),
        alignment: Alignment.center,
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusLg),
        textStyle: AppTextStyles.labelBold.copyWith(
          height: 1,
          color: AppColors.onSurfaceVariant,
        ),
      ),
      child: _ButtonContent(
        label: label,
        labelColor: AppColors.onSurfaceVariant,
        leading: leading,
      ),
    );

    if (!expand) {
      return button;
    }

    return SizedBox(width: double.infinity, child: button);
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.labelColor,
    this.leading,
  });

  final String label;
  final Color labelColor;
  final Widget? leading;

  static const TextHeightBehavior _labelHeightBehavior = TextHeightBehavior(
    applyHeightToFirstAscent: false,
    applyHeightToLastDescent: false,
  );

  TextStyle get _labelStyle =>
      AppTextStyles.labelBold.copyWith(height: 1, color: labelColor);

  @override
  Widget build(BuildContext context) {
    final labelWidget = Text(
      label,
      style: _labelStyle,
      textHeightBehavior: _labelHeightBehavior,
    );

    if (leading == null) {
      return labelWidget;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(child: leading!),
        SizedBox(width: AppSpacing.stackSm.w),
        labelWidget,
      ],
    );
  }
}
