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

/// Credits for the app developer and company.
class CreditsDialog extends StatelessWidget {
  const CreditsDialog._({
    required this.routeAnimation,
    required this.onDismiss,
  });

  final Animation<double> routeAnimation;
  final VoidCallback onDismiss;

  static const Duration animationDuration = Duration(milliseconds: 300);

  static Future<void> show(BuildContext context) {
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
        return CreditsDialog._(
          routeAnimation: animation,
          onDismiss: () {
            unawaited(AppAudioScope.read(dialogContext).playSwipe());
            Navigator.of(dialogContext).pop();
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
          child: _CreditsDialogCard(onDismiss: onDismiss),
        ),
      ),
    );
  }
}

class _CreditsDialogCard extends StatelessWidget {
  const _CreditsDialogCard({required this.onDismiss});

  final VoidCallback onDismiss;

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
                decoration: const BoxDecoration(
                  color: AppColors.surfaceMist,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: SvgPicture.asset(
                    IconConstant.credits,
                    width: 28.w,
                    height: 28.w,
                    colorFilter: const ColorFilter.mode(
                      AppColors.onSurface,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.stackLg.h),
              Text(
                'Credits',
                textAlign: TextAlign.center,
                style: AppTextStyles.displayLg.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              SizedBox(height: AppSpacing.stackSm.h),
              Text(
                '${AppConstants.appName} is designed and built by',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLg.copyWith(color: AppColors.outline),
              ),
              SizedBox(height: AppSpacing.stackLg.h),
              const _CreditsEntry(
                label: 'Developer',
                name: 'Karim Fawzy',
              ),
              SizedBox(height: AppSpacing.stackMd.h),
              const _CreditsEntry(
                label: 'Company',
                name: 'AllTerrainTech',
              ),
              SizedBox(height: AppSpacing.stackLg.h),
              PrimaryButton(label: 'OK', onPressed: onDismiss),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreditsEntry extends StatelessWidget {
  const _CreditsEntry({required this.label, required this.name});

  final String label;
  final String name;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.containerPadding.w,
          AppSpacing.stackMd.h,
          AppSpacing.containerPadding.w,
          AppSpacing.stackMd.h,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: AppTextStyles.labelBold.copyWith(
                      color: AppColors.outline,
                      letterSpacing: 0.7,
                    ),
                  ),
                  SizedBox(height: AppSpacing.stackSm.h),
                  Text(
                    name,
                    style: AppTextStyles.headlineSm.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
