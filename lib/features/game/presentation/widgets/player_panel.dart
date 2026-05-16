import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/image_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/game_status.dart';
import '../../domain/models/player.dart';
import '../state/game_cubit.dart';
import '../state/game_state.dart';

/// Player card: inactive (muted white + 1px border) vs active (accent ring + glow).
class PlayerPanel extends StatelessWidget {
  const PlayerPanel({super.key, required this.player});

  static const Duration _panelAnimDuration = Duration(milliseconds: 220);
  static const Curve _panelAnimCurve = Curves.easeOutCubic;
  static const Duration _contentOpacityDuration = Duration(milliseconds: 320);
  static const Curve _contentOpacityCurve = Curves.easeInOutCubic;
  static const double _inactiveContentOpacity = 0.55;

  final Player player;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameCubit, GameState>(
      buildWhen: (prev, next) =>
          prev.snapshot.currentPlayer != next.snapshot.currentPlayer ||
          prev.snapshot.status != next.snapshot.status ||
          prev.snapshot.winner != next.snapshot.winner,
      builder: (context, state) {
        final snap = state.snapshot;
        final isPlaying = snap.status == GameStatus.playing;
        final isWinner = snap.status == GameStatus.won && snap.winner == player;
        final isTurnActive = isPlaying && snap.currentPlayer == player;
        final highlighted = isTurnActive || isWinner;

        final subtitleText = isWinner
            ? 'WINNER'
            : (isTurnActive ? 'YOUR TURN' : 'Waiting');
        final showWaitingDots = isPlaying && !isTurnActive;
        final isX = player == Player.x;
        final accent = isX ? AppColors.softCoral : AppColors.primary;

        final inactiveAvatarBg = isX
            ? AppColors.softCoral.withValues(alpha: 0.2)
            : AppColors.primaryContainer.withValues(alpha: 0.2);
        final activeAvatarBg = isX
            ? AppColors.softCoral.withValues(alpha: 0.3)
            : AppColors.primaryContainer.withValues(alpha: 0.3);

        final avatarSize = 49.w;
        final iconSizeLarge = isX ? 25.5.w : 29.w;
        final iconSizeSmall = isX ? 17.5.w : 20.w;

        final titleStyleInactive = AppTextStyles.bodyMd.copyWith(
          fontWeight: FontWeight.w400,
          height: 26 / 16,
          color: AppColors.onSurfaceVariant,
        );
        final subtitleStyleInactive = AppTextStyles.labelSm.copyWith(
          fontWeight: FontWeight.w400,
          height: 14 / 12,
          color: AppColors.outline,
        );
        final titleStyleActive = AppTextStyles.bodyMd.copyWith(
          fontWeight: FontWeight.w600,
          height: 26 / 16,
          color: accent,
        );
        final subtitleStyleActive = AppTextStyles.labelSm.copyWith(
          fontWeight: FontWeight.w500,
          height: 14 / 12,
          letterSpacing: 0.6,
          color: accent,
        );

        final padding = highlighted
            ? EdgeInsets.all(16.w)
            : EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 18.h);

        return _PlayerPanelCard(
          active: highlighted,
          pulse: isTurnActive,
          accent: accent,
          padding: padding,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: _AnimatedPlayerContentOpacity(
                  highlighted: highlighted,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: avatarSize,
                        height: avatarSize,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: highlighted ? activeAvatarBg : inactiveAvatarBg,
                          ),
                          child: Center(
                            child: AnimatedContainer(
                              duration: _panelAnimDuration,
                              curve: _panelAnimCurve,
                              width: highlighted ? iconSizeLarge : iconSizeSmall,
                              height: highlighted ? iconSizeLarge : iconSizeSmall,
                              alignment: Alignment.center,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: SvgPicture.asset(
                                  isX ? IconConstant.x : IconConstant.o,
                                  width: iconSizeLarge,
                                  height: iconSizeLarge,
                                  colorFilter: ColorFilter.mode(
                                    accent,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 7.h),
                      Text(
                        isX ? 'Player X' : 'Player O',
                        style: highlighted ? titleStyleActive : titleStyleInactive,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 2.h),
                      _PlayerStatusLabel(
                        label: subtitleText,
                        style: highlighted
                            ? subtitleStyleActive
                            : subtitleStyleInactive,
                        showWaitingDots: showWaitingDots,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnimatedPlayerContentOpacity extends StatefulWidget {
  const _AnimatedPlayerContentOpacity({
    required this.highlighted,
    required this.child,
  });

  final bool highlighted;
  final Widget child;

  @override
  State<_AnimatedPlayerContentOpacity> createState() =>
      _AnimatedPlayerContentOpacityState();
}

class _AnimatedPlayerContentOpacityState
    extends State<_AnimatedPlayerContentOpacity>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: PlayerPanel._contentOpacityDuration,
    );
    _opacity = Tween<double>(
      begin: PlayerPanel._inactiveContentOpacity,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: PlayerPanel._contentOpacityCurve,
      ),
    );
    _controller.value = widget.highlighted ? 1 : 0;
  }

  @override
  void didUpdateWidget(_AnimatedPlayerContentOpacity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlighted == oldWidget.highlighted) return;
    if (widget.highlighted) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}

class _PlayerStatusLabel extends StatelessWidget {
  const _PlayerStatusLabel({
    required this.label,
    required this.style,
    required this.showWaitingDots,
  });

  final String label;
  final TextStyle style;
  final bool showWaitingDots;

  @override
  Widget build(BuildContext context) {
    if (!showWaitingDots) {
      return Text(label, style: style, textAlign: TextAlign.center);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: style, textAlign: TextAlign.center),
        SizedBox(width: 3.w),
        _WaitingDots(color: style.color ?? AppColors.outline, dotSize: 2.5.r),
      ],
    );
  }
}

class _WaitingDots extends StatefulWidget {
  const _WaitingDots({required this.color, required this.dotSize});

  final Color color;
  final double dotSize;

  @override
  State<_WaitingDots> createState() => _WaitingDotsState();
}

class _WaitingDotsState extends State<_WaitingDots>
    with SingleTickerProviderStateMixin {
  static const Duration _duration = Duration(milliseconds: 1400);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _dotPulse(int index) {
    final shifted = (_controller.value + index * 0.14) % 1;
    final wave = shifted < 0.5 ? shifted * 2 : (1 - shifted) * 2;
    return Curves.easeInOutSine.transform(wave);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final pulse = _dotPulse(index);
            final scale = lerpDouble(0.9, 1.06, pulse)!;
            final alpha = lerpDouble(0.42, 0.72, pulse)!;

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.dotSize * 0.18),
              child: Transform.scale(
                scale: scale,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: alpha),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(dimension: widget.dotSize),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Card shell: smooth turn transitions on the surface, subtle pulse on active glow.
class _PlayerPanelCard extends StatefulWidget {
  const _PlayerPanelCard({
    required this.active,
    required this.pulse,
    required this.accent,
    required this.padding,
    required this.child,
  });

  final bool active;
  final bool pulse;
  final Color accent;
  final EdgeInsets padding;
  final Widget child;

  @override
  State<_PlayerPanelCard> createState() => _PlayerPanelCardState();
}

class _PlayerPanelCardState extends State<_PlayerPanelCard>
    with SingleTickerProviderStateMixin {
  static const Duration _panelAnimDuration = PlayerPanel._panelAnimDuration;
  static const Curve _panelAnimCurve = PlayerPanel._panelAnimCurve;
  static const Duration _pulseDuration = Duration(milliseconds: 1600);

  static const double _glowBlurMin = 12;
  static const double _glowBlurMax = 22;
  static const double _glowSpreadMin = -4;
  static const double _glowSpreadMax = 0;
  static const double _glowAlphaMin = 0.26;
  static const double _glowAlphaMax = 0.42;

  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: _pulseDuration,
    );
    _pulse = CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut);
    _syncPulse();
  }

  @override
  void didUpdateWidget(_PlayerPanelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse != oldWidget.pulse) {
      _syncPulse();
    }
  }

  void _syncPulse() {
    if (widget.pulse) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  BoxDecoration _surfaceDecoration({required bool active}) {
    if (active) {
      return BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(color: widget.accent, width: 2),
      );
    }
    return BoxDecoration(
      color: AppColors.surfaceContainerLowest.withValues(alpha: 0.8),
      borderRadius: AppSpacing.borderRadiusLg,
      border: Border.all(color: AppColors.surfaceVariant, width: 1),
    );
  }

  List<BoxShadow> _inactiveShadow() => [
    BoxShadow(
      color: AppColors.inkNavy.withValues(alpha: 0.05),
      offset: const Offset(0, 2),
      blurRadius: 8,
      spreadRadius: -2,
    ),
  ];

  List<BoxShadow> _activeGlowShadow(double t) => [
    BoxShadow(
      color: widget.accent.withValues(
        alpha: lerpDouble(_glowAlphaMin, _glowAlphaMax, t)!,
      ),
      blurRadius: lerpDouble(_glowBlurMin, _glowBlurMax, t)!,
      spreadRadius: lerpDouble(_glowSpreadMin, _glowSpreadMax, t)!,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final borderRadius = AppSpacing.borderRadiusLg;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (widget.active)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                return DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    boxShadow: _activeGlowShadow(_pulse.value),
                  ),
                );
              },
            ),
          ),
        AnimatedContainer(
          duration: _panelAnimDuration,
          curve: _panelAnimCurve,
          clipBehavior: Clip.antiAlias,
          padding: widget.padding,
          decoration: _surfaceDecoration(
            active: widget.active,
          ).copyWith(boxShadow: widget.active ? null : _inactiveShadow()),
          child: widget.child,
        ),
      ],
    );
  }
}
