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
import 'match_result.dart';

/// Accent tints for result symbol + ambient glows (softer than board marks).
abstract final class _ResultPalette {
  Color get accent;

  Color get symbol => accent.withValues(alpha: 0.88);

  Color get symbolGlow => accent.withValues(alpha: 0.12);

  Color get ambientGlow => accent.withValues(alpha: 0.05);

  Color get mutedAccent => accent.withValues(alpha: 0.75);

  static _ResultPalette forResult(MatchResultKind kind) => switch (kind) {
    MatchResultKind.xWin => _WinnerPalette(Player.x),
    MatchResultKind.oWin => _WinnerPalette(Player.o),
    MatchResultKind.draw => _DrawPalette(),
  };
}

final class _WinnerPalette extends _ResultPalette {
  _WinnerPalette(this.winner);

  final Player winner;

  @override
  Color get accent =>
      winner == Player.x ? AppColors.softCoral : AppColors.primary;
}

final class _DrawPalette extends _ResultPalette {
  _DrawPalette();

  @override
  Color get accent => AppColors.outline;
}

/// Shared match result modal for X win, O win, and draw (tokens only).
class MatchResultDialog extends StatelessWidget {
  const MatchResultDialog._({
    required this.result,
    required this.onPlayAgain,
    required this.onBackToHome,
    required this.routeAnimation,
  });

  final MatchResult result;
  final VoidCallback onPlayAgain;
  final VoidCallback onBackToHome;
  final Animation<double> routeAnimation;

  static const Duration animationDuration = Duration(milliseconds: 300);

  static Future<void> show(
    BuildContext context, {
    required MatchResult result,
    required VoidCallback onPlayAgain,
    required VoidCallback onBackToHome,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: animationDuration,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return MatchResultDialog._(
          result: result,
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

  String get _title => switch (result.kind) {
    MatchResultKind.xWin => 'X Wins!',
    MatchResultKind.oWin => 'O Wins!',
    MatchResultKind.draw => "It's a Draw!",
  };

  String get _body => switch (result.kind) {
    MatchResultKind.draw => 'No winner this round. Try another match.',
    MatchResultKind.xWin || MatchResultKind.oWin =>
      'Strategic mastery achieved.',
  };

  String _symbolAsset() => switch (result.kind) {
    MatchResultKind.xWin => IconConstant.x,
    MatchResultKind.oWin => IconConstant.o,
    MatchResultKind.draw => IconConstant.draw,
  };

  String _formatDuration() {
    final d = Duration(milliseconds: result.matchDurationMs);
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m.toString()}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = _ResultPalette.forResult(result.kind);
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
          child: _MatchResultDialogCard(
            title: _title,
            body: _body,
            symbolAsset: _symbolAsset(),
            palette: palette,
            totalMoves: result.totalMoves,
            matchDurationLabel: _formatDuration(),
            onPlayAgain: onPlayAgain,
            onBackToHome: onBackToHome,
          ),
        ),
      ),
    );
  }
}

class _MatchResultDialogCard extends StatelessWidget {
  const _MatchResultDialogCard({
    required this.title,
    required this.body,
    required this.symbolAsset,
    required this.palette,
    required this.totalMoves,
    required this.matchDurationLabel,
    required this.onPlayAgain,
    required this.onBackToHome,
  });

  final String title;
  final String body;
  final String symbolAsset;
  final _ResultPalette palette;
  final int totalMoves;
  final String matchDurationLabel;
  final VoidCallback onPlayAgain;
  final VoidCallback onBackToHome;

  @override
  Widget build(BuildContext context) {
    final symbolSize = 72.r;

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
              _ResultSymbol(
                asset: symbolAsset,
                size: symbolSize,
                color: palette.symbol,
                glowColor: palette.symbolGlow,
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
                body,
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
                palette: palette,
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

class _ActionButtonsWithAmbient extends StatelessWidget {
  const _ActionButtonsWithAmbient({
    required this.palette,
    required this.onPlayAgain,
    required this.onBackToHome,
  });

  final _ResultPalette palette;
  final VoidCallback onPlayAgain;
  final VoidCallback onBackToHome;

  static const double _orbSize = 256;
  static const double _orbBlurSigma = 30;
  static const double _orbInsetSide = 79;
  static const double _orbInsetBottom = 74;

  @override
  Widget build(BuildContext context) {
    final glow = palette.ambientGlow;
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
                  palette.mutedAccent,
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

class _ResultSymbol extends StatelessWidget {
  const _ResultSymbol({
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
