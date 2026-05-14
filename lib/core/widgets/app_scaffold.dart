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
    this.fullWidthHeader = false,
  });

  final Widget child;
  final Widget? header;
  final EdgeInsetsGeometry? padding;
  final bool safeAreaTop;
  final bool safeAreaBottom;

  /// When true and [header] is set, the header spans the full width of the
  /// screen; [child] alone receives horizontal [padding].
  final bool fullWidthHeader;

  @override
  Widget build(BuildContext context) {
    final contentPadding =
        padding ??
        EdgeInsets.symmetric(horizontal: AppSpacing.containerPadding.w);

    final useSurfaceChrome = fullWidthHeader && header != null;
    final scaffoldBackground = useSurfaceChrome
        ? AppColors.surface
        : AppColors.warmIvory;

    final Widget columnChild;
    if (useSurfaceChrome) {
      final bodyInsets = contentPadding.resolve(Directionality.of(context));
      columnChild = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header!,
          Expanded(
            child: ColoredBox(
              color: AppColors.warmIvory,
              child: Padding(
                padding: bodyInsets.copyWith(
                  top: bodyInsets.top + AppSpacing.stackMd.h,
                ),
                child: child,
              ),
            ),
          ),
        ],
      );
    } else {
      columnChild = Padding(
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
      );
    }

    return Scaffold(
      backgroundColor: scaffoldBackground,
      body: SafeArea(
        top: safeAreaTop,
        bottom: safeAreaBottom,
        child: columnChild,
      ),
    );
  }
}
