import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/constants/image_constants.dart';
import '../../core/theme/app_spacing.dart';
import 'app_icon_button.dart';

class ScreenHeader extends StatelessWidget {
  ScreenHeader({
    super.key,
    this.leading,
    this.leadingIconAsset,
    this.onLeadingPressed,
    this.leadingSemanticLabel,
    Widget? center,
    this.trailing,
  }) : center = center ?? _defaultHeaderCenter();

  final Widget? leading;
  final String? leadingIconAsset;
  final VoidCallback? onLeadingPressed;
  final String? leadingSemanticLabel;
  final Widget center;
  final Widget? trailing;

  static Widget _defaultHeaderCenter() {
    return Image.asset(
      ImageConstant.logo,
      height: AppSpacing.stackLg * 1.2,
      fit: BoxFit.contain,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sideSize = AppSpacing.stackLg.w + AppSpacing.stackMd.w;

    return Row(
      children: [
        leading ??
            _HeaderSlot(
              size: sideSize,
              child: leadingIconAsset == null
                  ? null
                  : AppIconButton(
                      iconAsset: leadingIconAsset!,
                      onPressed: onLeadingPressed,
                      semanticLabel: leadingSemanticLabel,
                    ),
            ),
        Expanded(child: Center(child: center)),
        _HeaderSlot(size: sideSize, child: trailing),
      ],
    );
  }
}

class _HeaderSlot extends StatelessWidget {
  const _HeaderSlot({required this.size, this.child});

  final double size;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(dimension: size, child: child);
  }
}
