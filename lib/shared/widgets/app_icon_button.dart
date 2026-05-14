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
    this.size,
    this.iconSize,
    this.transparentMaterial = false,
  });

  final String iconAsset;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final Color backgroundColor;
  final Color iconColor;

  /// Square tap target; defaults to §ScreenHeader control (48 logical scaled).
  final double? size;

  /// SVG size; defaults to [AppSpacing.containerPadding] or half of [size].
  final double? iconSize;

  /// Ink on a clear circle (e.g. TopAppBar icon per Figma).
  final bool transparentMaterial;

  @override
  Widget build(BuildContext context) {
    final buttonSize =
        size ?? (AppSpacing.stackLg.w + AppSpacing.stackMd.w);
    final svgSize = iconSize ??
        (size != null ? size! * 0.5 : AppSpacing.containerPadding.w);

    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox.square(
        dimension: buttonSize,
        child: Material(
          type: transparentMaterial
              ? MaterialType.transparency
              : MaterialType.canvas,
          color: transparentMaterial ? Colors.transparent : backgroundColor,
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
                width: svgSize,
                height: svgSize,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
