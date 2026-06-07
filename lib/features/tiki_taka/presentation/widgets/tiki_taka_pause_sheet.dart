import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/image_constants.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/modal_backdrop.dart';
import '../../../../core/widgets/primary_button.dart';
import '../state/tiki_taka_cubit.dart';

/// In-match pause menu for Tiki-Taka 1P mode.
class TikiTakaPauseSheet extends StatelessWidget {
  const TikiTakaPauseSheet._({
    required this.cubit,
    required this.navigator,
    required this.sheetContext,
    required this.resumeTimerOnClose,
    required this.routeAnimation,
  });

  @visibleForTesting
  const TikiTakaPauseSheet.forTest({
    super.key,
    required this.cubit,
    required this.navigator,
    required this.sheetContext,
    required this.resumeTimerOnClose,
    required this.routeAnimation,
  });

  final TikiTakaCubit cubit;
  final NavigatorState navigator;
  final BuildContext sheetContext;
  final ValueNotifier<bool> resumeTimerOnClose;
  final Animation<double> routeAnimation;

  static const Duration animationDuration = Duration(milliseconds: 300);

  static bool _isVisible = false;

  static bool get isVisible => _isVisible;

  @visibleForTesting
  static void resetVisibilityForTest() {
    _isVisible = false;
  }

  @visibleForTesting
  static const Key resumeButtonKey = Key('tiki_pause_resume');

  @visibleForTesting
  static const Key restartButtonKey = Key('tiki_pause_restart');

  @visibleForTesting
  static const Key goHomeButtonKey = Key('tiki_pause_go_home');

  static Future<void> show(BuildContext context) {
    if (_isVisible) {
      return Future<void>.value();
    }

    final cubit = context.read<TikiTakaCubit>();
    final navigator = Navigator.of(context);
    final resumeTimerOnClose = ValueNotifier(true);
    final localizations = MaterialLocalizations.of(context);

    cubit.pauseTimer();
    _isVisible = true;
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: localizations.modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: animationDuration,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return TikiTakaPauseSheet._(
          cubit: cubit,
          navigator: navigator,
          sheetContext: dialogContext,
          resumeTimerOnClose: resumeTimerOnClose,
          routeAnimation: animation,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    ).whenComplete(() {
      _isVisible = false;
      if (resumeTimerOnClose.value && !cubit.isClosed) {
        cubit.resumeTimer();
      }
      resumeTimerOnClose.dispose();
    });
  }

  void _popSheet({bool resumeTimer = true}) {
    resumeTimerOnClose.value = resumeTimer;
    Navigator.of(sheetContext).pop();
  }

  void _goHome() {
    _popSheet(resumeTimer: false);
    cubit.exitMatch();
    navigator.pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final backdropCurve = CurvedAnimation(
      parent: routeAnimation,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    final sheetCurve = CurvedAnimation(
      parent: routeAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final sheetSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(sheetCurve);

    return AnimatedBuilder(
      animation: backdropCurve,
      builder: (context, child) {
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: ModalBackdrop(
                  progress: backdropCurve.value,
                  onTap: () => _popSheet(),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SlideTransition(position: sheetSlide, child: child),
              ),
            ],
          ),
        );
      },
      child: Padding(
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
                SizedBox(height: AppSpacing.stackMd.h),
                Text(
                  'Paused',
                  style: AppTextStyles.titleMd.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                SizedBox(height: AppSpacing.stackLg.h),
                PrimaryButton(
                  key: resumeButtonKey,
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
                  onPressed: () => _popSheet(),
                ),
                SizedBox(height: AppSpacing.gridGutter.h),
                _MenuTile(
                  key: restartButtonKey,
                  iconAsset: IconConstant.restart,
                  label: 'Restart Match',
                  onTap: () {
                    _popSheet(resumeTimer: false);
                    unawaited(cubit.restart());
                  },
                ),
                SizedBox(height: AppSpacing.gridGutter.h),
                _MenuTile(
                  key: goHomeButtonKey,
                  iconAsset: IconConstant.logout,
                  label: 'Exit to Home',
                  destructive: true,
                  onTap: _goHome,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    super.key,
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
    final borderColor = destructive
        ? AppColors.errorContainer
        : AppColors.surfaceContainerHighest;
    final titleColor = destructive
        ? AppColors.error
        : AppColors.onSurfaceVariant;
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
