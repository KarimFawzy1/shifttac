import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/game_constants.dart';
import '../../../../core/constants/image_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../game/presentation/widgets/board_cell.dart';

/// Visual shell for onboarding / how-to-play mini boards.
enum MiniBoardStyle {
  /// Frosted white cells (`css/Onboarding1ClassicStart.css`).
  classic,

  /// Gameplay-adjacent cells (`css/Onboarding2TheShiftMechanic.css`).
  game,
}

/// One frame of a 3×3 board (row-major, length 9).
class MiniBoardFrame {
  const MiniBoardFrame(this.cells);

  final List<BoardCellAppearance> cells;

  static const int cellCount = 9;
}

/// Reusable 3×3 preview; cell visuals match [BoardCell] from gameplay (P7).
class MiniBoardPreview extends StatelessWidget {
  const MiniBoardPreview({
    super.key,
    required this.frame,
    this.style = MiniBoardStyle.game,
    this.size,
    this.highlightIndex,
    this.showTapIndicatorOnIndex,
  });

  final MiniBoardFrame frame;
  final MiniBoardStyle style;
  final double? size;
  final int? highlightIndex;
  final int? showTapIndicatorOnIndex;

  @override
  Widget build(BuildContext context) {
    final boardSide = size ?? 256.w;
    final gap = style == MiniBoardStyle.classic
        ? AppSpacing.stackMd.w
        : AppSpacing.gridGutter.w;

    final grid = LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth;
        final cellSide = (side - gap * 2) / 3;

        return SizedBox(
          width: side,
          height: side,
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: List.generate(MiniBoardFrame.cellCount, (index) {
              final appearance = index < frame.cells.length
                  ? frame.cells[index]
                  : BoardCellAppearance.empty;

              Widget cell = _MiniBoardCell(
                appearance: appearance,
                style: style,
                side: cellSide,
                highlighted: highlightIndex == index,
              );

              if (showTapIndicatorOnIndex == index) {
                cell = Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    cell,
                    Positioned(
                      right: -12.w,
                      bottom: -16.h,
                      child: SvgPicture.asset(
                        IconConstant.tap,
                        width: 20.w,
                        height: 24.h,
                        colorFilter: const ColorFilter.mode(
                          AppColors.inkNavy,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ],
                );
              }

              return SizedBox(
                width: cellSide,
                height: cellSide,
                child: cell,
              );
            }),
          ),
        );
      },
    );

    final paddedGrid = Padding(
      padding: EdgeInsets.all(
        style == MiniBoardStyle.classic ? AppSpacing.stackMd.w : AppSpacing.stackMd.w,
      ),
      child: grid,
    );

    if (style == MiniBoardStyle.classic) {
      return SizedBox(
        width: boardSide,
        height: boardSide,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl.r),
            border: Border.all(
              color: AppColors.surfaceVariant.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.inkNavy.withValues(alpha: 0.08),
                offset: Offset(0, 12.h),
                blurRadius: 40.r,
                spreadRadius: -12.r,
              ),
            ],
          ),
          child: paddedGrid,
        ),
      );
    }

    return SizedBox(
      width: boardSide,
      height: boardSide,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.inkNavy.withValues(alpha: 0.06),
              offset: Offset(0, 8.h),
              blurRadius: 24.r,
            ),
          ],
        ),
        child: paddedGrid,
      ),
    );
  }
}

class _MiniBoardCell extends StatelessWidget {
  const _MiniBoardCell({
    required this.appearance,
    required this.style,
    required this.side,
    required this.highlighted,
  });

  final BoardCellAppearance appearance;
  final MiniBoardStyle style;
  final double side;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    if (style == MiniBoardStyle.classic) {
      return _ClassicMiniCell(
        appearance: appearance,
        side: side,
        highlighted: highlighted,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlighted ? AppColors.surfaceMist : AppColors.surface,
        borderRadius: AppSpacing.borderRadiusDefault,
        border: highlighted
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.5),
                width: 2,
              )
            : null,
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: AppColors.inkNavy.withValues(alpha: 0.1),
                  offset: Offset(0, 2.h),
                  blurRadius: 4.r,
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x0D000000),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
      ),
      child: SizedBox(
        width: side,
        height: side,
        child: BoardCell(
          appearance: appearance,
          onTap: () {},
          interactive: false,
        ),
      ),
    );
  }
}

/// Classic onboarding cells — white tiles; marks match [BoardCell] colors/opacity.
class _ClassicMiniCell extends StatelessWidget {
  const _ClassicMiniCell({
    required this.appearance,
    required this.side,
    required this.highlighted,
  });

  final BoardCellAppearance appearance;
  final double side;
  final bool highlighted;

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
        return AppColors.secondaryContainer;
      case BoardCellAppearance.oSolid:
      case BoardCellAppearance.oFaded:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _iconAsset;
    final iconSize = side * 0.32;
    Widget? mark;
    if (icon != null) {
      mark = SvgPicture.asset(
        icon,
        width: iconSize,
        height: iconSize,
        colorFilter: ColorFilter.mode(_markColor, BlendMode.srcIn),
      );
      if (_isFaded) {
        mark = Opacity(
          opacity: GameConstants.fadedMarkOpacity,
          child: mark,
        );
      }
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.surfaceMist
            : AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.borderRadiusMd,
        boxShadow: [
          BoxShadow(
            color: AppColors.inkNavy.withValues(alpha: 0.03),
            offset: Offset(0, 4.h),
            blurRadius: 16.r,
          ),
        ],
      ),
      child: SizedBox(
        width: side,
        height: side,
        child: Center(child: mark),
      ),
    );
  }
}

/// Animated shift demo for onboarding page 2.
class MiniBoardShiftAnimation extends StatefulWidget {
  const MiniBoardShiftAnimation({super.key, this.size});

  final double? size;

  @override
  State<MiniBoardShiftAnimation> createState() => _MiniBoardShiftAnimationState();
}

class _MiniBoardShiftAnimationState extends State<MiniBoardShiftAnimation> {
  static final List<MiniBoardFrame> _frames = [
    MiniBoardFrame(const [
      BoardCellAppearance.empty,
      BoardCellAppearance.xSolid,
      BoardCellAppearance.oSolid,
      BoardCellAppearance.empty,
      BoardCellAppearance.empty,
      BoardCellAppearance.empty,
      BoardCellAppearance.oSolid,
      BoardCellAppearance.empty,
      BoardCellAppearance.empty,
    ]),
    MiniBoardFrame(const [
      BoardCellAppearance.empty,
      BoardCellAppearance.xFaded,
      BoardCellAppearance.oSolid,
      BoardCellAppearance.empty,
      BoardCellAppearance.empty,
      BoardCellAppearance.empty,
      BoardCellAppearance.oSolid,
      BoardCellAppearance.empty,
      BoardCellAppearance.xSolid,
    ]),
    MiniBoardFrame(const [
      BoardCellAppearance.empty,
      BoardCellAppearance.empty,
      BoardCellAppearance.oSolid,
      BoardCellAppearance.empty,
      BoardCellAppearance.empty,
      BoardCellAppearance.empty,
      BoardCellAppearance.oSolid,
      BoardCellAppearance.empty,
      BoardCellAppearance.xSolid,
    ]),
  ];

  int _frameIndex = 0;

  @override
  void initState() {
    super.initState();
    _scheduleNextFrame();
  }

  void _scheduleNextFrame() {
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() {
        _frameIndex = (_frameIndex + 1) % _frames.length;
      });
      _scheduleNextFrame();
    });
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frames[_frameIndex];
    final highlightIndex = _frameIndex == 1 ? 8 : null;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: MiniBoardPreview(
        key: ValueKey<int>(_frameIndex),
        frame: frame,
        style: MiniBoardStyle.game,
        size: widget.size,
        highlightIndex: highlightIndex,
      ),
    );
  }
}
