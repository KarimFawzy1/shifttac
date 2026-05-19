import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../game/presentation/widgets/board_cell.dart';

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
    this.size,
    this.highlightIndex,
    this.showTapIndicatorOnIndex,
  });

  final MiniBoardFrame frame;
  final double? size;
  final int? highlightIndex;
  final int? showTapIndicatorOnIndex;

  @override
  Widget build(BuildContext context) {
    final boardSide = size ?? 256.w;
    final gap = AppSpacing.gridGutter.w;

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
                      child: Text('👀', style: TextStyle(fontSize: 22.sp)),
                    ),
                  ],
                );
              }

              return SizedBox(width: cellSide, height: cellSide, child: cell);
            }),
          ),
        );
      },
    );

    final paddedGrid = Padding(
      padding: EdgeInsets.all(AppSpacing.stackMd.w),
      child: grid,
    );

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
    required this.side,
    required this.highlighted,
  });

  final BoardCellAppearance appearance;
  final double side;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
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

/// Animated shift demo for onboarding page 2.
class MiniBoardShiftAnimation extends StatefulWidget {
  const MiniBoardShiftAnimation({
    super.key,
    this.size,
    this.persistentCells = const {},
    this.showIndicatorOnIndex,
  });

  final double? size;

  /// Merged into every animation frame (e.g. background marks on the board).
  final Map<int, BoardCellAppearance> persistentCells;

  /// Cell that shows the 👀 cue (e.g. the mark queued to shift away).
  final int? showIndicatorOnIndex;

  @override
  State<MiniBoardShiftAnimation> createState() =>
      _MiniBoardShiftAnimationState();
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

  MiniBoardFrame _frameWithPersistentCells(MiniBoardFrame frame) {
    final overlay = widget.persistentCells;
    if (overlay.isEmpty) {
      return frame;
    }

    final cells = List<BoardCellAppearance>.from(frame.cells);
    for (final entry in overlay.entries) {
      final index = entry.key;
      if (index >= 0 && index < MiniBoardFrame.cellCount) {
        cells[index] = entry.value;
      }
    }
    return MiniBoardFrame(cells);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      return MiniBoardPreview(
        frame: _frameWithPersistentCells(_frames.last),
        size: widget.size,
        highlightIndex: 8,
        showTapIndicatorOnIndex: widget.showIndicatorOnIndex,
      );
    }

    final frame = _frameWithPersistentCells(_frames[_frameIndex]);
    final highlightIndex = _frameIndex == 1 ? 8 : null;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: MiniBoardPreview(
        key: ValueKey<int>(_frameIndex),
        frame: frame,
        size: widget.size,
        highlightIndex: highlightIndex,
        showTapIndicatorOnIndex: widget.showIndicatorOnIndex,
      ),
    );
  }
}
