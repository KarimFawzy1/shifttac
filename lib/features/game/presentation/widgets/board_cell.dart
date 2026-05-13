import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/game_constants.dart';
import '../../../../core/constants/image_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Visual state for a single board cell (driven by [GameBoard]; cells do not read queues).
enum BoardCellAppearance {
  empty,
  xSolid,
  oSolid,
  xFaded,
  oFaded,
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
