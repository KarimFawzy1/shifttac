import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/audio/app_audio.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/modal_backdrop.dart';
import '../../../game/domain/models/bot_difficulty.dart';
import '../../../game/domain/models/game_session_config.dart';

/// Second step after choosing **Classic** in [AiModeSelectionDialog].
class AiDifficultyDialog extends StatelessWidget {
  const AiDifficultyDialog._({
    required this.routeAnimation,
    required this.onDismiss,
    required this.onDifficultySelected,
  });

  final Animation<double> routeAnimation;
  final VoidCallback onDismiss;
  final void Function(BotDifficulty difficulty) onDifficultySelected;

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
        return AiDifficultyDialog._(
          routeAnimation: animation,
          onDismiss: () {
            unawaited(AppAudioScope.read(dialogContext).playSwipe());
            Navigator.of(dialogContext).pop();
          },
          onDifficultySelected: (difficulty) {
            unawaited(AppAudioScope.read(dialogContext).playGameStart());
            Navigator.of(dialogContext).pop();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!hostContext.mounted) {
                return;
              }
              Navigator.of(hostContext).pushNamed(
                AppRoutes.game,
                arguments: GameSessionConfig.classicAi(difficulty),
              );
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
          child: _AiDifficultyDialogCard(
            onDismiss: onDismiss,
            onDifficultySelected: onDifficultySelected,
          ),
        ),
      ),
    );
  }
}

class _AiDifficultyDialogCard extends StatelessWidget {
  const _AiDifficultyDialogCard({
    required this.onDismiss,
    required this.onDifficultySelected,
  });

  final VoidCallback onDismiss;
  final void Function(BotDifficulty difficulty) onDifficultySelected;

  static const _options = <({BotDifficulty difficulty, String helper})>[
    (
      difficulty: BotDifficulty.easy,
      helper: 'Random moves for relaxed practice.',
    ),
    (
      difficulty: BotDifficulty.intermediate,
      helper: 'Blocks threats and takes wins.',
    ),
    (
      difficulty: BotDifficulty.hard,
      helper: 'Optimal classic Tic Tac Toe.',
    ),
  ];

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
                  'Choose Difficulty',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.displayLg.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                SizedBox(height: AppSpacing.stackLg.h),
                for (var i = 0; i < _options.length; i++) ...[
                  if (i > 0) SizedBox(height: AppSpacing.stackMd.h),
                  _AiDifficultyOptionCard(
                    title: _titleFor(_options[i].difficulty),
                    subtitle: _options[i].helper,
                    onTap: () => onDifficultySelected(_options[i].difficulty),
                  ),
                ],
                SizedBox(height: AppSpacing.stackLg.h),
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    key: const Key('ai-difficulty-cancel'),
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

  static String _titleFor(BotDifficulty difficulty) => switch (difficulty) {
    BotDifficulty.easy => 'Easy',
    BotDifficulty.intermediate => 'Intermediate',
    BotDifficulty.hard => 'Hard',
  };
}

class _AiDifficultyOptionCard extends StatelessWidget {
  const _AiDifficultyOptionCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerHighest,
      elevation: 0,
      borderRadius: AppSpacing.borderRadiusMd,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Feedback.forTap(context);
          onTap();
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppSpacing.borderRadiusMd,
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.containerPadding.w,
              AppSpacing.containerPadding.w,
              AppSpacing.containerPadding.w,
              AppSpacing.containerPadding.h,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.headlineSm.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                SizedBox(height: AppSpacing.stackSm.h),
                Text(
                  subtitle,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
