import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/board_winning_line_overlay.dart';
import '../../../game/domain/logic/win_checker.dart';
import '../../domain/models/tiki_game_status.dart';
import '../state/tiki_taka_cubit.dart';
import '../state/tiki_taka_state.dart';
import 'tiki_taka_cell.dart';

/// 3×3 playable Tiki-Taka grid driven by [TikiTakaCubit].
class TikiTakaBoard extends StatelessWidget {
  const TikiTakaBoard({
    super.key,
    this.cellAspectRatio,
    this.onOutcomeRevealComplete,
  });

  /// Width-to-height ratio for each cell. When null, cells stay square.
  final double? cellAspectRatio;

  /// Called after the first-win line or full-board line sequence finishes.
  final VoidCallback? onOutcomeRevealComplete;

  static const Color _lineColor = AppColors.teal;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TikiTakaCubit, TikiTakaState>(
      buildWhen: (previous, current) =>
          previous.game.cells != current.game.cells ||
          previous.game.winningLine != current.game.winningLine ||
          previous.status != current.status ||
          previous.activeCell != current.activeCell ||
          previous.isPlayable != current.isPlayable ||
          previous.inputLocked != current.inputLocked,
      builder: (context, state) {
        final gap = AppSpacing.gridGutter.w;
        final overlay = _buildWinningLineOverlay(state, gap);

        return DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: AppSpacing.borderRadiusXl,
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x141D2330),
                offset: Offset(0, 8),
                blurRadius: 16,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(gap),
            child: Stack(
              fit: StackFit.expand,
              children: [
                GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: gap,
                    crossAxisSpacing: gap,
                    childAspectRatio: cellAspectRatio ?? 1,
                  ),
                  itemCount: 9,
                  itemBuilder: (context, index) {
                    final row = index ~/ 3;
                    final col = index % 3;
                    final cell = state.game.cellAt(row, col);
                    final active = state.activeCell;
                    final isActive =
                        active != null &&
                        active.row == row &&
                        active.col == col;

                    return TikiTakaCell(
                      cell: cell,
                      interactive: state.isPlayable,
                      isActive: isActive,
                      onTap: () => _onCellTapped(context, row, col),
                    );
                  },
                ),
                if (overlay != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: RepaintBoundary(child: overlay),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget? _buildWinningLineOverlay(TikiTakaState state, double gap) {
    final status = state.status;
    final winningLine = state.game.winningLine;

    switch (status) {
      case TikiGameStatus.completed:
        return BoardWinningLinesSequenceReveal(
          lines: WinChecker.tikiCompletionRevealOrder,
          color: _lineColor,
          gap: gap,
          revealDuration: kTikiCompletionLineRevealDuration,
          settleDuration: kTikiCompletionLineSettleDuration,
          onRevealComplete: onOutcomeRevealComplete,
        );
      case TikiGameStatus.firstWin:
        if (winningLine == null) {
          return null;
        }
        return BoardWinningLineReveal(
          winningLine: winningLine,
          color: _lineColor,
          gap: gap,
          revealDuration: kTikiFirstWinLineRevealDuration,
          settleDuration: kTikiFirstWinLineSettleDuration,
          onRevealComplete: onOutcomeRevealComplete,
        );
      case TikiGameStatus.initial ||
          TikiGameStatus.loadingBoard ||
          TikiGameStatus.ongoing ||
          TikiGameStatus.continuing ||
          TikiGameStatus.lost:
        return null;
    }
  }

  void _onCellTapped(BuildContext context, int row, int col) {
    final result = context.read<TikiTakaCubit>().onCellTapped(row, col);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }

    switch (result) {
      case TikiCellTapResult.openedSearch:
        break;
      case TikiCellTapResult.rejectedOccupied:
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('This cell is already filled.'),
              duration: Duration(seconds: 2),
            ),
          );
      case TikiCellTapResult.rejectedLocked:
      case TikiCellTapResult.rejectedNotPlayable:
      case TikiCellTapResult.rejectedDialogOpen:
        break;
    }
  }
}
