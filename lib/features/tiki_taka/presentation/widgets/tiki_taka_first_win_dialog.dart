import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/image_constants.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/modal_backdrop.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../state/tiki_taka_cubit.dart';
import 'tiki_taka_outcome_dialog_layout.dart';

/// Shown once when the player completes their first 3-in-a-row on a board.
class TikiTakaFirstWinDialog extends StatelessWidget {
  const TikiTakaFirstWinDialog._({
    required this.routeAnimation,
    required this.elapsed,
    required this.hearts,
    required this.onContinue,
    required this.onRestart,
    required this.onGoHome,
  });

  @visibleForTesting
  const TikiTakaFirstWinDialog.forTest({
    super.key,
    required this.routeAnimation,
    required this.elapsed,
    required this.hearts,
    required this.onContinue,
    required this.onRestart,
    required this.onGoHome,
  });

  final Animation<double> routeAnimation;
  final Duration elapsed;
  final int hearts;
  final VoidCallback onContinue;
  final VoidCallback onRestart;
  final VoidCallback onGoHome;

  static const Duration animationDuration = Duration(milliseconds: 300);

  static bool _isVisible = false;

  static bool get isVisible => _isVisible;

  @visibleForTesting
  static void resetVisibilityForTest() {
    _isVisible = false;
  }

  @visibleForTesting
  static const Key continueButtonKey = Key('tiki_first_win_continue');

  @visibleForTesting
  static const Key restartButtonKey = Key('tiki_first_win_restart');

  @visibleForTesting
  static const Key goHomeButtonKey = Key('tiki_first_win_go_home');

  static Future<void> show(BuildContext context) {
    if (_isVisible) {
      return Future<void>.value();
    }

    final cubit = context.read<TikiTakaCubit>();
    final navigator = Navigator.of(context);
    final elapsed = cubit.state.game.elapsed;
    final hearts = cubit.state.hearts;

    _isVisible = true;
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: animationDuration,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return TikiTakaFirstWinDialog._(
          routeAnimation: animation,
          elapsed: elapsed,
          hearts: hearts,
          onContinue: () {
            Navigator.of(dialogContext).pop();
            cubit.continueAfterFirstWin();
          },
          onRestart: () {
            Navigator.of(dialogContext).pop();
            unawaited(cubit.restart());
          },
          onGoHome: () {
            Navigator.of(dialogContext).pop();
            cubit.exitMatch();
            navigator.pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    ).whenComplete(() {
      _isVisible = false;
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
    final contentScale = Tween<double>(begin: 0.96, end: 1).animate(contentCurve);

    return AnimatedBuilder(
      animation: backdropCurve,
      builder: (context, child) {
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: ModalBackdrop(progress: backdropCurve.value),
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
          child: TikiOutcomeDialogCard(
            title: 'Line complete!',
            body: 'You got three in a row. Keep going to fill the whole board.',
            stats: TikiOutcomeStatsCard(elapsed: elapsed, hearts: hearts),
            icon: SvgPicture.asset(
              IconConstant.target,
              width: 56.r,
              height: 56.r,
              colorFilter: const ColorFilter.mode(
                AppColors.teal,
                BlendMode.srcIn,
              ),
            ),
            actions: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PrimaryButton(
                  key: continueButtonKey,
                  label: 'Continue Playing',
                  onPressed: onContinue,
                ),
                SizedBox(height: AppSpacing.stackMd.h),
                SecondaryButton(
                  key: restartButtonKey,
                  label: 'Restart',
                  leading: SvgPicture.asset(
                    IconConstant.restart,
                    width: 18.w,
                    height: 18.w,
                    colorFilter: const ColorFilter.mode(
                      AppColors.teal,
                      BlendMode.srcIn,
                    ),
                  ),
                  onPressed: onRestart,
                ),
                SizedBox(height: AppSpacing.stackMd.h),
                SecondaryButton(
                  key: goHomeButtonKey,
                  label: 'Go Home',
                  leading: SvgPicture.asset(
                    IconConstant.home,
                    width: 18.w,
                    height: 18.w,
                    colorFilter: const ColorFilter.mode(
                      AppColors.teal,
                      BlendMode.srcIn,
                    ),
                  ),
                  onPressed: onGoHome,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
