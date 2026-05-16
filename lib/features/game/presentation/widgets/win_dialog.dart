import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/image_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/modal_backdrop.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../domain/models/player.dart';

/// Winner accent tints for symbol + ambient glows (softer than board marks).
abstract final class _WinnerPalette {
  static Color accent(Player winner) =>
      winner == Player.x ? AppColors.softCoral : AppColors.primary;

  static Color symbol(Player winner) => accent(winner).withValues(alpha: 0.88);

  static Color symbolGlow(Player winner) =>
      accent(winner).withValues(alpha: 0.12);

  static Color ambientGlow(Player winner) =>
      accent(winner).withValues(alpha: 0.05);

  static Color mutedAccent(Player winner) =>
      accent(winner).withValues(alpha: 0.75);
}

/// Win celebration modal aligned with `css/WinDialog.css` (tokens only).
class WinDialog extends StatelessWidget {
  const WinDialog._({
    required this.winner,
    required this.totalMoves,
    required this.matchDurationMs,
    required this.onPlayAgain,
    required this.onBackToHome,
    required this.routeAnimation,
  });

  final Player winner;
  final int totalMoves;
  final int matchDurationMs;
  final VoidCallback onPlayAgain;
  final VoidCallback onBackToHome;
  final Animation<double> routeAnimation;

  static const Duration _animationDuration = Duration(milliseconds: 300);

  static Future<void> show(
    BuildContext context, {
    required Player winner,
    required int totalMoves,
    required int matchDurationMs,
    required VoidCallback onPlayAgain,
    required VoidCallback onBackToHome,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: _animationDuration,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return WinDialog._(
          winner: winner,
          totalMoves: totalMoves,
          matchDurationMs: matchDurationMs,
          routeAnimation: animation,
          onPlayAgain: () {
            Navigator.of(dialogContext).pop();
            onPlayAgain();
          },
          onBackToHome: () {
            Navigator.of(dialogContext).pop();
            onBackToHome();
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    );
  }

  String get _title => winner == Player.x ? 'X Wins!' : 'O Wins!';

  String _formatDuration() {
    final d = Duration(milliseconds: matchDurationMs);
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m.toString()}:${s.toString().padLeft(2, '0')}';
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
          child: _WinDialogCard(
            title: _title,
            winner: winner,
            totalMoves: totalMoves,
            matchDurationLabel: _formatDuration(),
            onPlayAgain: onPlayAgain,
            onBackToHome: onBackToHome,
          ),
        ),
      ),
    );
  }
}

class _WinDialogCard extends StatelessWidget {
  const _WinDialogCard({
    required this.title,
    required this.winner,
    required this.totalMoves,
    required this.matchDurationLabel,
    required this.onPlayAgain,
    required this.onBackToHome,
  });

  final String title;
  final Player winner;
  final int totalMoves;
  final String matchDurationLabel;
  final VoidCallback onPlayAgain;
  final VoidCallback onBackToHome;

  @override
  Widget build(BuildContext context) {
    final symbolSize = 72.r;
    final symbolAsset = winner == Player.x ? IconConstant.x : IconConstant.o;

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
              _WinnerSymbol(
                asset: symbolAsset,
                size: symbolSize,
                color: _WinnerPalette.symbol(winner),
                glowColor: _WinnerPalette.symbolGlow(winner),
              ),
              SizedBox(height: AppSpacing.stackLg.h),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.displayLg.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              SizedBox(height: AppSpacing.stackSm.h),
              Text(
                'Strategic mastery achieved.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLg.copyWith(color: AppColors.outline),
              ),
              SizedBox(height: AppSpacing.stackLg.h),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: AppSpacing.borderRadiusMd,
                  border: Border.all(color: AppColors.surfaceContainerHigh),
                ),
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.stackMd.w),
                  child: Column(
                    children: [
                      _StatRow(
                        label: 'Total moves',
                        value: '$totalMoves',
                        showDivider: true,
                      ),
                      _StatRow(
                        label: 'Match time',
                        value: matchDurationLabel,
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.stackLg.h),
              _ActionButtonsWithAmbient(
                winner: winner,
                onPlayAgain: onPlayAgain,
                onBackToHome: onBackToHome,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Play Again + Back to Home with winner-colored ambient blur (`WinDialog.css`).
class _ActionButtonsWithAmbient extends StatelessWidget {
  const _ActionButtonsWithAmbient({
    required this.winner,
    required this.onPlayAgain,
    required this.onBackToHome,
  });

  final Player winner;
  final VoidCallback onPlayAgain;
  final VoidCallback onBackToHome;

  static const double _orbSize = 256;
  static const double _orbBlurSigma = 30;
  /// `WinDialog.css` ambient orbs sit ~79px outside the action column edges.
  static const double _orbInsetSide = 79;
  static const double _orbInsetBottom = 74;

  @override
  Widget build(BuildContext context) {
    final glow = _WinnerPalette.ambientGlow(winner);
    final orb = _orbSize.r;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -_orbInsetSide.w,
          bottom: -_orbInsetBottom.h,
          child: _BlurredOrb(
            size: orb,
            color: glow,
            blurSigma: _orbBlurSigma,
          ),
        ),
        Positioned(
          right: -_orbInsetSide.w,
          bottom: -_orbInsetBottom.h,
          child: _BlurredOrb(
            size: orb,
            color: glow,
            blurSigma: _orbBlurSigma,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrimaryButton(
              label: 'Play Again',
              leading: SvgPicture.asset(
                IconConstant.restart,
                width: 18.w,
                height: 18.w,
                colorFilter: const ColorFilter.mode(
                  AppColors.onPrimary,
                  BlendMode.srcIn,
                ),
              ),
              onPressed: onPlayAgain,
            ),
            SizedBox(height: AppSpacing.stackMd.h),
            SecondaryButton(
              label: 'Back to Home',
              leading: SvgPicture.asset(
                IconConstant.home,
                width: 18.w,
                height: 18.w,
                colorFilter: ColorFilter.mode(
                  _WinnerPalette.mutedAccent(winner),
                  BlendMode.srcIn,
                ),
              ),
              onPressed: onBackToHome,
            ),
          ],
        ),
      ],
    );
  }
}

/// Circular fill + Gaussian blur (`filter: blur` in `WinDialog.css`).
class _BlurredOrb extends StatelessWidget {
  const _BlurredOrb({
    required this.size,
    required this.color,
    required this.blurSigma,
  });

  final double size;
  final Color color;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

/// Large symbol with `WinDialog.css` overlay blur (`-24px` inset, `12px` blur).
class _WinnerSymbol extends StatelessWidget {
  const _WinnerSymbol({
    required this.asset,
    required this.size,
    required this.color,
    required this.glowColor,
  });

  final String asset;
  final double size;
  final Color color;
  final Color glowColor;

  static const double _glowInset = 24;
  static const double _glowBlurSigma = 12;

  @override
  Widget build(BuildContext context) {
    final inset = _glowInset.r;
    final frame = size + inset * 2;

    return SizedBox(
      width: frame,
      height: frame,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: _BlurredOrb(
              size: frame,
              color: glowColor,
              blurSigma: _glowBlurSigma,
            ),
          ),
          SvgPicture.asset(
            asset,
            width: size,
            height: size,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.showDivider,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.stackSm.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: AppTextStyles.labelBold.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.outlineVariant.withValues(alpha: 0.5),
          ),
      ],
    );
  }
}
