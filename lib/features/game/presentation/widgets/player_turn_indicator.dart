import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/game_status.dart';
import '../../domain/models/player.dart';
import '../state/game_cubit.dart';
import '../state/game_state.dart';

/// Animated label for current turn or win result.
class PlayerTurnIndicator extends StatelessWidget {
  const PlayerTurnIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameCubit, GameState>(
      buildWhen: (prev, next) =>
          prev.snapshot.currentPlayer != next.snapshot.currentPlayer ||
          prev.snapshot.status != next.snapshot.status ||
          prev.snapshot.winner != next.snapshot.winner,
      builder: (context, state) {
        final snap = state.snapshot;
        final String label;
        switch (snap.status) {
          case GameStatus.won:
            label = snap.winner == Player.x ? 'X wins!' : 'O wins!';
          case GameStatus.playing:
            label = snap.currentPlayer == Player.x ? "X's turn" : "O's turn";
          case GameStatus.idle:
            label = '—';
        }

        final accent = snap.status == GameStatus.won && snap.winner != null
            ? (snap.winner == Player.x ? AppColors.softCoral : AppColors.teal)
            : AppColors.primary;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.08),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Column(
            key: ValueKey(label),
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.softMist,
                  borderRadius: AppSpacing.borderRadiusFull,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D1D2330),
                      offset: Offset(0, 2),
                      blurRadius: 8,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12.r,
                        height: 12.r,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.25),
                              blurRadius: 16,
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        label,
                        style: AppTextStyles.headlineSm.copyWith(
                          color: accent,
                        ),
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
