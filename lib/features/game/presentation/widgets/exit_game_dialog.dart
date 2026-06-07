import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/audio/app_audio.dart';
import '../../../../core/constants/image_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/modal_backdrop.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/models/game_status.dart';
import '../state/game_cubit.dart';

/// Optional pause/resume hooks when [ExitGameDialog.show] is used outside
/// classic [GameCubit] gameplay.
class ExitGameDialogLifecycle {
  const ExitGameDialogLifecycle({
    required this.isMatchActive,
    required this.pauseMatch,
    required this.resumeMatch,
    required this.isSessionOpen,
  });

  final bool Function() isMatchActive;
  final VoidCallback pauseMatch;
  final VoidCallback resumeMatch;
  final bool Function() isSessionOpen;
}

/// Confirms leaving an in-progress match before returning home.
class ExitGameDialog extends StatelessWidget {
  const ExitGameDialog._({
    required this.onStay,
    required this.onExit,
    required this.routeAnimation,
  });

  final VoidCallback onStay;
  final VoidCallback onExit;
  final Animation<double> routeAnimation;

  static const Duration _animationDuration = Duration(milliseconds: 300);

  /// Returns `true` when the player confirms leaving the match.
  static Future<bool> show(
    BuildContext context, {
    ExitGameDialogLifecycle? lifecycle,
  }) {
    late final bool shouldResumeOnDismiss;
    late final VoidCallback pauseMatch;
    late final VoidCallback resumeMatch;
    late final bool Function() isSessionOpen;

    if (lifecycle != null) {
      shouldResumeOnDismiss = lifecycle.isMatchActive();
      pauseMatch = lifecycle.pauseMatch;
      resumeMatch = lifecycle.resumeMatch;
      isSessionOpen = lifecycle.isSessionOpen;
    } else {
      final cubit = context.read<GameCubit>();
      shouldResumeOnDismiss =
          cubit.state.snapshot.status == GameStatus.playing;
      pauseMatch = cubit.pauseMatch;
      resumeMatch = cubit.resumeMatch;
      isSessionOpen = () => !cubit.isClosed;
    }

    if (shouldResumeOnDismiss) {
      pauseMatch();
    }
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
        return ExitGameDialog._(
          routeAnimation: animation,
          onStay: () {
            unawaited(AppAudioScope.read(dialogContext).playSwipe());
            Navigator.of(dialogContext).pop(false);
          },
          onExit: () {
            unawaited(AppAudioScope.read(dialogContext).playSwipe());
            Navigator.of(dialogContext).pop(true);
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    ).then((confirmed) {
      final exitConfirmed = confirmed ?? false;
      if (isSessionOpen() && shouldResumeOnDismiss && !exitConfirmed) {
        resumeMatch();
      }
      return exitConfirmed;
    });
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
          child: _ExitGameDialogCard(onStay: onStay, onExit: onExit),
        ),
      ),
    );
  }
}

class _ExitGameDialogCard extends StatelessWidget {
  const _ExitGameDialogCard({required this.onStay, required this.onExit});

  final VoidCallback onStay;
  final VoidCallback onExit;

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
                'Leave match?',
                textAlign: TextAlign.center,
                style: AppTextStyles.displayLg.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              SizedBox(height: AppSpacing.stackSm.h),
              Text(
                'Your match progress will be lost if you exit now.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLg.copyWith(color: AppColors.outline),
              ),
              SizedBox(height: AppSpacing.stackLg.h),
              PrimaryButton(label: 'Keep Playing', onPressed: onStay),
              SizedBox(height: AppSpacing.stackMd.h),
              _ExitToHomeButton(onPressed: onExit),
            ],
          ),
        ),
      ),
    );
  }
}

/// Destructive action aligned with `PauseMenu.css` “Exit to Home”.
class _ExitToHomeButton extends StatelessWidget {
  const _ExitToHomeButton({required this.onPressed});

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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: SvgPicture.asset(
                IconConstant.home,
                width: 18.w,
                height: 18.w,
                colorFilter: const ColorFilter.mode(
                  AppColors.error,
                  BlendMode.srcIn,
                ),
              ),
            ),
            SizedBox(width: AppSpacing.stackSm.w),
            Text(
              'Exit to Home',
              style: AppTextStyles.labelBold.copyWith(
                height: 1,
                color: AppColors.error,
              ),
              textHeightBehavior: const TextHeightBehavior(
                applyHeightToFirstAscent: false,
                applyHeightToLastDescent: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
