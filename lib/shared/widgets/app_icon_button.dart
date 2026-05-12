import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.iconAsset,
    required this.onPressed,
    this.semanticLabel,
    this.backgroundColor = AppColors.surfaceContainerLowest,
    this.iconColor = AppColors.inkNavy,
  });

  final String iconAsset;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final buttonSize = AppSpacing.stackLg.w + AppSpacing.stackMd.w;
    final iconSize = AppSpacing.containerPadding.w;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox.square(
        dimension: buttonSize,
        child: Material(
          color: backgroundColor,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed == null
                ? null
                : () {
                    Feedback.forTap(context);
                    onPressed!();
                  },
            child: Center(
              child: SvgPicture.asset(
                iconAsset,
                width: iconSize,
                height: iconSize,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
