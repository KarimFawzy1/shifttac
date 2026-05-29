import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/audio/app_audio.dart';
import '../../../../core/constants/image_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/modal_backdrop.dart';
import 'ai_difficulty_dialog.dart';

/// First step after tapping **Play vs AI** on the home screen.
class AiModeSelectionDialog extends StatelessWidget {
  const AiModeSelectionDialog._({
    required this.routeAnimation,
    required this.onDismiss,
    required this.onClassicSelected,
  });

  final Animation<double> routeAnimation;
  final VoidCallback onDismiss;
  final VoidCallback onClassicSelected;

  static const Duration animationDuration = Duration(milliseconds: 300);

  static Future<void> show(BuildContext context) {
    final hostContext = context;
    unawaited(AppAudioScope.read(context).playSwipe());
    final barrierLabel = MaterialLocalizations.of(
      context,
    ).modalBarrierDismissLabel;

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: barrierLabel,
      barrierColor: Colors.transparent,
      transitionDuration: animationDuration,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return AiModeSelectionDialog._(
          routeAnimation: animation,
          onDismiss: () {
            unawaited(AppAudioScope.read(dialogContext).playSwipe());
            Navigator.of(dialogContext).pop();
          },
          onClassicSelected: () {
            unawaited(AppAudioScope.read(dialogContext).playGameStart());
            Navigator.of(dialogContext).pop();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!hostContext.mounted) {
                return;
              }
              unawaited(AiDifficultyDialog.show(hostContext));
            });
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    );
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
                  onTap: onDismiss,
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
          child: _AiModeSelectionDialogCard(
            onDismiss: onDismiss,
            onClassicSelected: onClassicSelected,
          ),
        ),
      ),
    );
  }
}

class _AiModeSelectionDialogCard extends StatelessWidget {
  const _AiModeSelectionDialogCard({
    required this.onDismiss,
    required this.onClassicSelected,
  });

  final VoidCallback onDismiss;
  final VoidCallback onClassicSelected;

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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Play vs AI',
                textAlign: TextAlign.center,
                style: AppTextStyles.displayLg.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              SizedBox(height: AppSpacing.stackSm.h),
              Text(
                'AI opponents are available in classic mode for now.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLg.copyWith(color: AppColors.outline),
              ),
              SizedBox(height: AppSpacing.stackLg.h),
              _AiModeOptionCard(
                title: 'Classic',
                subtitle: 'Traditional 3x3 against the bot.',
                iconAsset: IconConstant.classicTicTacToe,
                enabled: true,
                onTap: onClassicSelected,
              ),
              SizedBox(height: AppSpacing.stackMd.h),
              _AiModeOptionCard(
                title: 'ShiftTac',
                subtitle: 'AI for shifting marks will arrive later.',
                iconAsset: IconConstant.multiplayer,
                enabled: false,
                badgeLabel: 'Coming Soon',
              ),
              SizedBox(height: AppSpacing.stackLg.h),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: onDismiss,
                  child: Text(
                    'Cancel',
                    style: AppTextStyles.labelBold.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiModeOptionCard extends StatelessWidget {
  const _AiModeOptionCard({
    required this.title,
    required this.subtitle,
    required this.iconAsset,
    required this.enabled,
    this.onTap,
    this.badgeLabel,
  });

  final String title;
  final String subtitle;
  final String iconAsset;
  final bool enabled;
  final VoidCallback? onTap;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.containerPadding.w,
        AppSpacing.containerPadding.w,
        AppSpacing.containerPadding.w,
        AppSpacing.containerPadding.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                iconAsset,
                width: 20.w,
                height: 20.w,
                colorFilter: ColorFilter.mode(
                  enabled
                      ? AppColors.onSurface
                      : AppColors.onSurfaceVariant,
                  BlendMode.srcIn,
                ),
              ),
              SizedBox(width: AppSpacing.stackSm.w),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.headlineSm.copyWith(
                    color: enabled
                        ? AppColors.onSurface
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              if (badgeLabel != null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: AppSpacing.borderRadiusFull,
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.stackSm.w,
                      vertical: 3.5.h,
                    ),
                    child: Text(
                      badgeLabel!,
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.outline,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: AppSpacing.stackSm.h),
          Text(
            subtitle,
            style: AppTextStyles.bodyMd.copyWith(
              color: enabled
                  ? AppColors.onSurfaceVariant
                  : AppColors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );

    if (!enabled) {
      return Opacity(
        opacity: 0.85,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHighest,
            borderRadius: AppSpacing.borderRadiusMd,
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: content,
        ),
      );
    }

    return Material(
      color: AppColors.surfaceContainerHighest,
      elevation: 0,
      borderRadius: AppSpacing.borderRadiusMd,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Feedback.forTap(context);
          onTap?.call();
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppSpacing.borderRadiusMd,
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: content,
        ),
      ),
    );
  }
}
