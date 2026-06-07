import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Static schematic for Tiki-Taka rules — fixture labels only, no gameplay state.
class HowToPlayTikiTakaPreview extends StatelessWidget {
  const HowToPlayTikiTakaPreview({super.key, this.size});

  final double? size;

  static const _columnLabels = ['Egypt', 'Premier League', 'Forward'];
  static const _rowLabels = ['Liverpool', 'Real Madrid', 'Barcelona'];

  @override
  Widget build(BuildContext context) {
    final boardSide = size ?? 168.w;
    final headerBand = boardSide * 0.22;
    final gap = AppSpacing.gridGutter.w;
    final cellSide = (boardSide - gap * 2) / 3;

    return SizedBox(
      width: boardSide + headerBand,
      height: boardSide + headerBand,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: headerBand,
            top: 0,
            right: 0,
            height: headerBand - gap,
            child: Row(
              children: [
                for (var index = 0; index < 3; index++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: index == 0 ? 0 : gap),
                      child: _HeaderChip(label: _columnLabels[index]),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            top: headerBand,
            width: headerBand - gap,
            height: boardSide,
            child: Column(
              children: [
                for (var index = 0; index < 3; index++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: index == 0 ? 0 : gap),
                      child: _HeaderChip(label: _rowLabels[index]),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            left: headerBand,
            top: headerBand,
            width: boardSide,
            height: boardSide,
            child: Wrap(
              spacing: gap,
              runSpacing: gap,
              children: List.generate(9, (index) {
                final isExampleCell = index == 0;
                return _PreviewCell(
                  side: cellSide,
                  label: isExampleCell ? 'Salah' : null,
                  highlighted: isExampleCell,
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppSpacing.borderRadiusSm,
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: AppTextStyles.labelBold.copyWith(
                color: AppColors.onSurface,
                fontSize: 10.sp,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewCell extends StatelessWidget {
  const _PreviewCell({
    required this.side,
    this.label,
    this.highlighted = false,
  });

  final double side;
  final String? label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: side,
      height: side,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: highlighted
              ? AppColors.primaryContainer.withValues(alpha: 0.35)
              : AppColors.surfaceContainerLowest,
          borderRadius: AppSpacing.borderRadiusSm,
          border: Border.all(
            color: highlighted
                ? AppColors.primary.withValues(alpha: 0.45)
                : AppColors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: label == null
            ? null
            : Center(
                child: Transform.rotate(
                  angle: -0.45,
                  child: Text(
                    label!,
                    style: AppTextStyles.labelBold.copyWith(
                      color: AppColors.onSurface,
                      fontSize: 11.sp,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
      ),
    );
  }
}
