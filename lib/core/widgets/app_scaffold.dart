import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.child,
    this.header,
    this.padding,
    this.safeAreaTop = true,
    this.safeAreaBottom = true,
  });

  final Widget child;
  final Widget? header;
  final EdgeInsetsGeometry? padding;
  final bool safeAreaTop;
  final bool safeAreaBottom;

  @override
  Widget build(BuildContext context) {
    final contentPadding =
        padding ??
        EdgeInsets.symmetric(horizontal: AppSpacing.containerPadding.w);

    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      body: SafeArea(
        top: safeAreaTop,
        bottom: safeAreaBottom,
        child: Padding(
          padding: contentPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (header != null) ...[
                header!,
                SizedBox(height: AppSpacing.stackMd.h),
              ],
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
