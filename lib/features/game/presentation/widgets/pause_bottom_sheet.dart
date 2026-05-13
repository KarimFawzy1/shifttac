import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/image_constants.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/primary_button.dart';
import '../state/game_cubit.dart';

/// Pause menu bottom sheet from `css/PauseMenu.css` (tokens only).
class PauseBottomSheet extends StatelessWidget {
  const PauseBottomSheet._({
    required this.cubit,
    required this.navigator,
    required this.sheetContext,
  });

  final GameCubit cubit;
  final NavigatorState navigator;
  final BuildContext sheetContext;

  static Future<void> show(BuildContext context) {
    final cubit = context.read<GameCubit>();
    final navigator = Navigator.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.inkNavy.withValues(alpha: 0.2),
      builder: (sheetContext) => PauseBottomSheet._(
        cubit: cubit,
        navigator: navigator,
        sheetContext: sheetContext,
      ),
    );
  }

  void _popSheet() {
    Navigator.of(sheetContext).pop();
  }

  void _goHome() {
    _popSheet();
    navigator.pushNamedAndRemoveUntil(
      AppRoutes.home,
      (route) => false,
    );
  }

  void _openRoute(String routeName) {
    _popSheet();
    navigator.pushNamed(routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.stackMd.w,
        right: AppSpacing.stackMd.w,
        bottom: AppSpacing.stackMd.h,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceMist,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl.r),
            bottom: Radius.circular(AppSpacing.radiusMd.r),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A1D2330),
              offset: Offset(0, -8),
              blurRadius: 32,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.containerPadding.w,
            AppSpacing.stackMd.h,
            AppSpacing.containerPadding.w,
            AppSpacing.containerPadding.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48.w,
                height: 6.h,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: AppSpacing.borderRadiusFull,
                ),
              ),
              SizedBox(height: AppSpacing.stackSm.h),
              Text(
                'Paused',
                style: AppTextStyles.titleMd.copyWith(color: AppColors.onSurface),
              ),
              SizedBox(height: AppSpacing.stackLg.h),
              PrimaryButton(
                label: 'Resume',
                leading: SvgPicture.asset(
                  IconConstant.resume,
                  width: 14.w,
                  height: 14.w,
                  colorFilter: const ColorFilter.mode(
                    AppColors.onPrimary,
                    BlendMode.srcIn,
                  ),
                ),
                onPressed: _popSheet,
              ),
              SizedBox(height: AppSpacing.gridGutter.h),
              _MenuTile(
                iconAsset: IconConstant.restart,
                label: 'Restart Match',
                onTap: () {
                  _popSheet();
                  cubit.restart();
                },
              ),
              SizedBox(height: AppSpacing.gridGutter.h),
              _MenuTile(
                iconAsset: IconConstant.howToPlay,
                label: 'How to Play',
                onTap: () => _openRoute(AppRoutes.howToPlay),
              ),
              SizedBox(height: AppSpacing.gridGutter.h),
              _MenuTile(
                iconAsset: IconConstant.settings,
                label: 'Settings',
                onTap: () => _openRoute(AppRoutes.settings),
              ),
              SizedBox(height: AppSpacing.gridGutter.h),
              _MenuTile(
                iconAsset: IconConstant.logout,
                label: 'Exit to Home',
                destructive: true,
                onTap: _goHome,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.iconAsset,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final String iconAsset;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        destructive ? AppColors.errorContainer : AppColors.surfaceContainerHighest;
    final titleColor = destructive ? AppColors.error : AppColors.onSurfaceVariant;
    final iconBg = destructive
        ? AppColors.errorContainer.withValues(alpha: 0.5)
        : AppColors.surfaceContainerHighest;
    final iconTint = destructive ? AppColors.error : AppColors.onSurfaceVariant;

    return Material(
      color: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusLg,
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Feedback.forTap(context);
          onTap();
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.containerPadding.w,
            vertical: AppSpacing.stackMd.h,
          ),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(10.w),
                  child: SvgPicture.asset(
                    iconAsset,
                    width: 20.w,
                    height: 20.w,
                    colorFilter: ColorFilter.mode(iconTint, BlendMode.srcIn),
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.stackMd.w),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.headlineSm.copyWith(color: titleColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
