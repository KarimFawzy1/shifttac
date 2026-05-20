import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/audio/app_audio.dart';
import '../../../../core/constants/game_constants.dart';
import '../../../../core/constants/image_constants.dart';
import '../../../../core/settings/app_settings_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/models/position.dart';
import '../state/game_cubit.dart';

/// Visual state for a single board cell (driven by [GameBoard]; cells do not read queues).
enum BoardCellAppearance {
  empty,
  xSolid,
  oSolid,
  xFaded,
  oFaded,
}

/// Fires gameplay haptics when [AppSettingsController.vibrationEnabled] is true.
abstract final class GameplayHaptics {
  GameplayHaptics._();

  static void onCellTapResult(BuildContext context, CellTapResult result) {
    final audio = AppAudioScope.read(context);
    switch (result) {
      case CellTapResult.accepted:
        unawaited(audio.playTap());
        if (AppSettingsScope.read(context).vibrationEnabled) {
          HapticFeedback.selectionClick();
        }
      case CellTapResult.rejectedInvalid:
      case CellTapResult.rejectedLocked:
      case CellTapResult.rejectedNotPlaying:
        unawaited(audio.playWrongTap());
        if (result == CellTapResult.rejectedInvalid &&
            AppSettingsScope.read(context).vibrationEnabled) {
          HapticFeedback.lightImpact();
        }
    }
  }

  static void onRestartTap(BuildContext context) {
    unawaited(AppAudioScope.read(context).playRestart());
    if (!AppSettingsScope.read(context).vibrationEnabled) {
      return;
    }
    HapticFeedback.selectionClick();
  }
}

/// Tappable board cell: routes taps through [GameCubit], haptics, and invalid shake.
class BoardCellTapTarget extends StatefulWidget {
  const BoardCellTapTarget({
    super.key,
    required this.appearance,
    required this.position,
    required this.interactive,
  });

  final BoardCellAppearance appearance;
  final Position position;
  final bool interactive;

  @override
  State<BoardCellTapTarget> createState() => _BoardCellTapTargetState();
}

class _BoardCellTapTargetState extends State<BoardCellTapTarget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: GameConstants.tapFeedbackMs),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onTap() {
    final result = context.read<GameCubit>().onCellTapped(widget.position);
    GameplayHaptics.onCellTapResult(context, result);
    if (result == CellTapResult.rejectedInvalid) {
      unawaited(_shakeController.forward(from: 0));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cell = BoardCell(
      appearance: widget.appearance,
      interactive: widget.interactive,
      onTap: _onTap,
    );

    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final t = _shakeController.value;
        final offset = t == 0
            ? 0.0
            : math.sin(t * math.pi * 6) * 6 * (1 - t);
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: cell,
    );
  }
}

class BoardCell extends StatelessWidget {
  const BoardCell({
    super.key,
    required this.appearance,
    required this.onTap,
    this.interactive = true,
  });

  final BoardCellAppearance appearance;
  final VoidCallback onTap;
  final bool interactive;

  bool get _isFaded =>
      appearance == BoardCellAppearance.xFaded ||
      appearance == BoardCellAppearance.oFaded;

  String? get _iconAsset {
    switch (appearance) {
      case BoardCellAppearance.empty:
        return null;
      case BoardCellAppearance.xSolid:
      case BoardCellAppearance.xFaded:
        return IconConstant.x;
      case BoardCellAppearance.oSolid:
      case BoardCellAppearance.oFaded:
        return IconConstant.o;
    }
  }

  Color get _markColor {
    switch (appearance) {
      case BoardCellAppearance.empty:
        return AppColors.onSurface;
      case BoardCellAppearance.xSolid:
      case BoardCellAppearance.xFaded:
        return AppColors.softCoral;
      case BoardCellAppearance.oSolid:
      case BoardCellAppearance.oFaded:
        return AppColors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _iconAsset;

    Widget cellFace = LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        final iconSize = side * 0.42;
        final mark = icon == null
            ? null
            : SvgPicture.asset(
                icon,
                width: iconSize,
                height: iconSize,
                colorFilter: ColorFilter.mode(_markColor, BlendMode.srcIn),
              );

        final content = mark == null
            ? null
            : _isFaded
                ? Opacity(
                    opacity: GameConstants.fadedMarkOpacity,
                    child: mark,
                  )
                : mark;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: AppSpacing.borderRadiusLg,
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D1D2330),
                offset: Offset(0, 2),
                blurRadius: 8,
                spreadRadius: -2,
              ),
            ],
          ),
          child: SizedBox(
            width: side,
            height: side,
            child: Center(child: content),
          ),
        );
      },
    );

    if (!interactive) {
      return cellFace;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusLg,
        child: cellFace,
      ),
    );
  }
}
