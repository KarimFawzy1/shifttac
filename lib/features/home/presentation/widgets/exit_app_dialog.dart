import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/audio/app_audio.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/image_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/modal_backdrop.dart';
import '../../../../core/widgets/primary_button.dart';

/// Confirms exiting the app from the main shell (Home / Rules / Settings).
class ExitAppDialog extends StatelessWidget {
  const ExitAppDialog._({
    required this.onStay,
    required this.onQuit,
    required this.routeAnimation,
  });

  final VoidCallback onStay;
  final VoidCallback onQuit;
  final Animation<double> routeAnimation;

  static const Duration _animationDuration = Duration(milliseconds: 300);

  /// Returns `true` when the user confirms quitting the app.
  static Future<bool> show(BuildContext context) {
    unawaited(AppAudioScope.read(context).playSwipe());
    final barrierLabel = MaterialLocalizations.of(
      context,
    ).modalBarrierDismissLabel;

    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: barrierLabel,
      barrierColor: Colors.transparent,
      transitionDuration: _animationDuration,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return ExitAppDialog._(
          routeAnimation: animation,
          onStay: () {
            unawaited(AppAudioScope.read(dialogContext).playSwipe());
            Navigator.of(dialogContext).pop(false);
          },
          onQuit: () {
            unawaited(AppAudioScope.read(dialogContext).playSwipe());
            Navigator.of(dialogContext).pop(true);
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    ).then((confirmed) => confirmed ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final backdropCurve = CurvedAnimation(
      parent: routeAnimation,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    final contentCurve = CurvedAnimation(
      parent: routeAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final contentFade = Tween<double>(begin: 0, end: 1).animate(contentCurve);
    final contentScale = Tween<double>(
      begin: 0.96,
      end: 1,
    ).animate(contentCurve);

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
                  onTap: onStay,
                ),
              ),
              Center(child: child),
            ],
          ),
        );
      },
      child: FadeTransition(
        opacity: contentFade,
        child: ScaleTransition(
          scale: contentScale,
          child: _ExitAppDialogCard(onStay: onStay, onQuit: onQuit),
        ),
      ),
    );
  }
}

class _ExitAppDialogCard extends StatelessWidget {
  const _ExitAppDialogCard({required this.onStay, required this.onQuit});

  final VoidCallback onStay;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      clipBehavior: Clip.none,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusXl,
        side: const BorderSide(color: AppColors.surfaceContainerHighest),
      ),
      insetPadding: EdgeInsets.symmetric(horizontal: AppSpacing.stackLg.w),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 336.w),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.containerPadding.w,
            AppSpacing.stackLg.h,
            AppSpacing.containerPadding.w,
            AppSpacing.stackMd.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.errorContainer.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: SvgPicture.asset(
                    IconConstant.logout,
                    width: 28.w,
                    height: 28.w,
                    colorFilter: const ColorFilter.mode(
                      AppColors.error,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.stackLg.h),
              Text(
                'Quit app?',
                textAlign: TextAlign.center,
                style: AppTextStyles.displayLg.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              SizedBox(height: AppSpacing.stackSm.h),
              Text(
                'Are you sure you want to close ${AppConstants.appName}?',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLg.copyWith(color: AppColors.outline),
              ),
              SizedBox(height: AppSpacing.stackLg.h),
              PrimaryButton(label: 'Stay', onPressed: onStay),
              SizedBox(height: AppSpacing.stackMd.h),
              _QuitAppButton(onPressed: onQuit),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuitAppButton extends StatelessWidget {
  const _QuitAppButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          Feedback.forTap(context);
          onPressed();
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surfaceContainerLowest,
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.errorContainer),
          minimumSize: Size.fromHeight(
            AppSpacing.stackLg.h + AppSpacing.stackMd.h,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.containerPadding.w,
          ),
          alignment: Alignment.center,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusLg,
          ),
          textStyle: AppTextStyles.labelBold.copyWith(
            height: 1,
            color: AppColors.error,
          ),
        ),
        child: Text(
          'Quit app',
          style: AppTextStyles.labelBold.copyWith(
            height: 1,
            color: AppColors.error,
          ),
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
        ),
      ),
    );
  }
}
