import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'how_to_play_step.dart';
import 'how_to_play_tiki_taka_preview.dart';

/// Tiki-Taka 1 Player rules for the How to Play screen.
class HowToPlayTikiTakaSection extends StatelessWidget {
  const HowToPlayTikiTakaSection({super.key, required this.compact});

  final bool compact;

  double get _previewSize => compact ? 168.w : 176.w;

  @override
  Widget build(BuildContext context) {
    var step = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _HowToPlayModeTitle(
          title: 'Tiki-Taka',
          subtitle: 'Football knowledge on a 3×3 board. Solo mode — no AI.',
        ),
        SizedBox(height: AppSpacing.stackLg.h),
        HowToPlayStep(
          stepNumber: ++step,
          title: 'The board',
          description:
              'Each playable cell is the intersection of a row attribute and a '
              'column attribute — for example Liverpool and Egypt. Three column '
              'headers sit above the board; three row headers sit on the left. '
              'Clubs, leagues, and nations use icons; positions show as text '
              '(for example Forward or Midfielder).',
          visual: HowToPlayTikiTakaPreview(size: _previewSize),
          semanticLabel:
              'Step $step. The board. Row and column attributes intersect in '
              'each cell.',
        ),
        SizedBox(height: AppSpacing.stackMd.h),
        HowToPlayStep(
          stepNumber: ++step,
          title: 'Search and select',
          description:
              'Tap an empty cell to open player search. Type a name, then pick '
              'a player from the results list. You must select from the list — '
              'free-text confirmation without a listed player is not allowed.',
          visual: _DialogHintCard(
            rowLabel: 'Liverpool',
            columnLabel: 'Egypt',
          ),
          semanticLabel:
              'Step $step. Search and select. Pick a listed player for the cell.',
        ),
        SizedBox(height: AppSpacing.stackMd.h),
        HowToPlayStep(
          stepNumber: ++step,
          title: 'Matching both attributes',
          description:
              'Your pick counts only when that player matches the row attribute '
              'and the column attribute independently. A player who fits only one '
              'side is still a wrong answer.',
          visual: HowToPlayTikiTakaPreview(size: _previewSize),
          semanticLabel:
              'Step $step. Valid answers must match both row and column '
              'attributes.',
        ),
        SizedBox(height: AppSpacing.stackMd.h),
        HowToPlayStep(
          stepNumber: ++step,
          title: 'Five hearts',
          description:
              'You start with five hearts. A wrong pick costs one heart — '
              'including a player who does not match both attributes, is not in '
              'the game database, or was already used on this board. At zero '
              'hearts, the match is lost.',
          visual: const _HeartsHintRow(count: 5),
          semanticLabel:
              'Step $step. Five hearts. Wrong answers remove one heart.',
        ),
        SizedBox(height: AppSpacing.stackMd.h),
        HowToPlayStep(
          stepNumber: ++step,
          title: 'One player per board',
          description:
              'Each footballer can only fill one cell. Selecting someone you '
              'already used counts as a wrong answer and removes a heart.',
          visual: const _DuplicateHint(),
          semanticLabel:
              'Step $step. Duplicate players are banned for the current board.',
        ),
        SizedBox(height: AppSpacing.stackMd.h),
        HowToPlayStep(
          stepNumber: ++step,
          title: 'First line wins',
          description:
              'Fill any complete row, column, or diagonal with valid players to '
              'reach the first win. You can then continue on the same board to '
              'fill every remaining cell.',
          visual: _WinLineHint(size: _previewSize),
          semanticLabel:
              'Step $step. Three in a row is the first win objective.',
        ),
        SizedBox(height: AppSpacing.stackMd.h),
        HowToPlayStep(
          stepNumber: ++step,
          title: 'Full board challenge',
          description:
              'After your first win, keep playing to name a valid player in all '
              'nine cells. Filling the whole board shows a completion screen with '
              'your final time and remaining hearts.',
          visual: _FullBoardHint(size: _previewSize),
          semanticLabel:
              'Step $step. Full board completion is the optional challenge.',
        ),
        SizedBox(height: AppSpacing.stackMd.h),
        HowToPlayStep(
          stepNumber: ++step,
          title: 'Match timer',
          description:
              'The timer starts when the board is ready to play. It stops if you '
              'lose, complete the full board, restart, or exit. If you continue '
              'after a first win, the timer keeps running until you finish the '
              'challenge or leave the match.',
          visual: const _TimerHintRow(),
          semanticLabel:
              'Step $step. Match timer rules for play and continue.',
        ),
        SizedBox(height: AppSpacing.stackMd.h),
        const HowToPlayTip(
          headline: 'Know your squads.\nOne name, one cell.',
          subtitle: 'Wrong guesses cost hearts. Plan before you search.',
        ),
      ],
    );
  }
}

class _HowToPlayModeTitle extends StatelessWidget {
  const _HowToPlayModeTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.titleMd.copyWith(color: AppColors.primary),
        ),
        SizedBox(height: AppSpacing.unit.h),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DialogHintCard extends StatelessWidget {
  const _DialogHintCard({
    required this.rowLabel,
    required this.columnLabel,
  });

  final String rowLabel;
  final String columnLabel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.stackMd.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$rowLabel × $columnLabel',
              textAlign: TextAlign.center,
              style: AppTextStyles.headlineSm.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            SizedBox(height: AppSpacing.stackSm.h),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: AppSpacing.borderRadiusSm,
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.stackSm.w,
                  vertical: AppSpacing.unit.h,
                ),
                child: Text(
                  'Search player…',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            SizedBox(height: AppSpacing.stackSm.h),
            Text(
              'Pick from the results list',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeartsHintRow extends StatelessWidget {
  const _HeartsHintRow({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < count; index++)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 3.w),
            child: Icon(
              Icons.favorite,
              color: AppColors.error,
              size: 22.r,
            ),
          ),
      ],
    );
  }
}

class _TimerHintRow extends StatelessWidget {
  const _TimerHintRow();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppSpacing.borderRadiusSm,
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.stackMd.w,
          vertical: AppSpacing.stackSm.h,
        ),
        child: Text(
          '02:45',
          textAlign: TextAlign.center,
          style: AppTextStyles.headlineSm.copyWith(
            color: AppColors.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _WinLineHint extends StatelessWidget {
  const _WinLineHint({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final gap = AppSpacing.gridGutter.w;
    final cellSide = (size - gap * 2) / 3;

    return SizedBox(
      width: size,
      height: size,
      child: Wrap(
        spacing: gap,
        runSpacing: gap,
        children: List.generate(9, (index) {
          final inWinLine = index == 0 || index == 1 || index == 2;
          return _PreviewFilledCell(
            side: cellSide,
            label: inWinLine ? 'Player' : null,
            highlighted: inWinLine,
          );
        }),
      ),
    );
  }
}

class _DuplicateHint extends StatelessWidget {
  const _DuplicateHint();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppSpacing.borderRadiusSm,
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.stackMd.w,
          vertical: AppSpacing.stackSm.h,
        ),
        child: Text(
          'Messi — already used',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMd.copyWith(
            color: AppColors.error,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _FullBoardHint extends StatelessWidget {
  const _FullBoardHint({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final gap = AppSpacing.gridGutter.w;
    final cellSide = (size - gap * 2) / 3;

    return SizedBox(
      width: size,
      height: size,
      child: Wrap(
        spacing: gap,
        runSpacing: gap,
        children: List.generate(
          9,
          (_) => _PreviewFilledCell(
            side: cellSide,
            label: 'Player',
            highlighted: true,
          ),
        ),
      ),
    );
  }
}

class _PreviewFilledCell extends StatelessWidget {
  const _PreviewFilledCell({
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
                child: Text(
                  label!,
                  style: AppTextStyles.labelBold.copyWith(
                    color: AppColors.onSurface,
                    fontSize: 10.sp,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
      ),
    );
  }
}
