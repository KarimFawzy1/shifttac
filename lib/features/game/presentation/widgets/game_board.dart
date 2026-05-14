import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/logic/game_engine.dart';
import '../../domain/logic/game_snapshot.dart';
import '../../domain/models/game_status.dart';
import '../../domain/models/player.dart';
import '../../domain/models/position.dart';
import '../state/game_cubit.dart';
import '../state/game_state.dart';
import 'board_cell.dart';

/// Maps engine snapshot → per-cell visuals. Queue reads stay in this file only.
BoardCellAppearance _appearanceFor(GameState state, Position position) {
  final snap = state.snapshot;
  final occupant = _occupant(snap, position);
  if (occupant == null) {
    return BoardCellAppearance.empty;
  }

  final playing = snap.status == GameStatus.playing;
  final oldest = playing
      ? GameEngine.oldestPositionFor(snap.currentPlayer, snap)
      : null;
  final faded = playing && oldest == position && occupant == snap.currentPlayer;

  if (occupant == Player.x) {
    return faded ? BoardCellAppearance.xFaded : BoardCellAppearance.xSolid;
  }
  return faded ? BoardCellAppearance.oFaded : BoardCellAppearance.oSolid;
}

Player? _occupant(GameSnapshot snapshot, Position position) {
  for (final m in snapshot.xMoves) {
    if (m.position == position) {
      return Player.x;
    }
  }
  for (final m in snapshot.oMoves) {
    if (m.position == position) {
      return Player.o;
    }
  }
  return null;
}

class GameBoard extends StatelessWidget {
  const GameBoard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameCubit, GameState>(
      buildWhen: (prev, next) =>
          prev.snapshot != next.snapshot ||
          prev.inputLocked != next.inputLocked,
      builder: (context, state) {
        final frozen = state.snapshot.status != GameStatus.playing;
        final gap = AppSpacing.gridGutter.w;

        return LayoutBuilder(
          builder: (context, constraints) {
            final side = constraints.maxWidth.isFinite && constraints.maxWidth > 0
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
                  child: AbsorbPointer(
                    absorbing: frozen,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                        return BoardCell(
                          appearance: _appearanceFor(state, p),
                          interactive: !frozen,
                          onTap: () =>
                              context.read<GameCubit>().onCellTapped(p),
                        );
                      },
                    ),
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
