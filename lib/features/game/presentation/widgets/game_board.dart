import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/board_winning_line_overlay.dart';
import '../../domain/models/player.dart';
import '../../domain/models/position.dart';
import '../state/game_cubit.dart';
import '../state/game_state.dart';
import 'board_appearance_mapper.dart';
import 'board_cell.dart';

class GameBoard extends StatelessWidget {
  const GameBoard({super.key, this.onWinningLineRevealComplete});

  final VoidCallback? onWinningLineRevealComplete;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameCubit, GameState>(
      buildWhen: (prev, next) =>
          prev.snapshot != next.snapshot ||
          prev.inputLocked != next.inputLocked,
      builder: (context, state) {
        final cubit = context.read<GameCubit>();
        final frozen = isBoardFrozen(state.snapshot.status);
        final botThinking = cubit.isBotTurn;
        final gap = AppSpacing.gridGutter.w;

        return LayoutBuilder(
          builder: (context, constraints) {
            final side =
                constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : 320.w;

            return SizedBox(
              width: side,
              height: side,
              child: DecoratedBox(
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
                      AbsorbPointer(
                        absorbing: frozen,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: gap,
                                crossAxisSpacing: gap,
                                childAspectRatio: 1,
                              ),
                          itemCount: 9,
                          itemBuilder: (context, index) {
                            final row = index ~/ 3;
                            final col = index % 3;
                            final p = Position(row: row, col: col);
                            return BoardCellTapTarget(
                              appearance: boardCellAppearanceFor(
                                rules: cubit.rules,
                                snapshot: state.snapshot,
                                position: p,
                              ),
                              position: p,
                              interactive: !frozen && !botThinking,
                            );
                          },
                        ),
                      ),
                      if (botThinking)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.inkNavy.withValues(
                                  alpha: 0.05,
                                ),
                                borderRadius: AppSpacing.borderRadiusXl,
                              ),
                            ),
                          ),
                        ),
                      if (state.snapshot.winningLine case final winningLine?)
                        if (state.snapshot.winner case final winner?)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: RepaintBoundary(
                                child: BoardWinningLineReveal(
                                  winningLine: winningLine,
                                  color: winner == Player.x
                                      ? AppColors.softCoral
                                      : AppColors.teal,
                                  gap: gap,
                                  onRevealComplete:
                                      onWinningLineRevealComplete,
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
