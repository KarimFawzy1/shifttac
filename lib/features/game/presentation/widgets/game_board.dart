import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/models/player.dart';
import '../../domain/models/position.dart';
import '../state/game_cubit.dart';
import '../state/game_state.dart';
import 'board_appearance_mapper.dart';
import 'board_cell.dart';

const Duration _winningLineRevealDuration = Duration(milliseconds: 560);
const Duration _winningLineSettleDuration = Duration(milliseconds: 90);

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
                                color: AppColors.inkNavy.withValues(alpha: 0.05),
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
                                child: _WinningLineReveal(
                                  winningLine: winningLine,
                                  winner: winner,
                                  gap: gap,
                                  onRevealComplete: onWinningLineRevealComplete,
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

class _WinningLineReveal extends StatefulWidget {
  const _WinningLineReveal({
    required this.winningLine,
    required this.winner,
    required this.gap,
    this.onRevealComplete,
  });

  final List<Position> winningLine;
  final Player winner;
  final double gap;
  final VoidCallback? onRevealComplete;

  @override
  State<_WinningLineReveal> createState() => _WinningLineRevealState();
}

class _WinningLineRevealState extends State<_WinningLineReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  String? _revealedLineKey;
  bool _completionReported = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _winningLineRevealDuration,
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _startRevealIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _WinningLineReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    _startRevealIfNeeded();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startRevealIfNeeded() {
    final lineKey = _lineKey(widget.winningLine, widget.winner);
    if (lineKey == _revealedLineKey) {
      return;
    }

    _revealedLineKey = lineKey;
    _completionReported = false;
    unawaited(_playReveal());
  }

  Future<void> _playReveal() async {
    try {
      await _controller.forward(from: 0).orCancel;
      await Future<void>.delayed(_winningLineSettleDuration);
    } catch (_) {
      return;
    }

    if (!mounted || _completionReported) {
      return;
    }

    _completionReported = true;
    widget.onRevealComplete?.call();
  }

  static String _lineKey(List<Position> line, Player winner) {
    return '${winner.name}:${line.map((p) => p.index).join('-')}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        return CustomPaint(
          painter: _WinningLinePainter(
            winningLine: widget.winningLine,
            winner: widget.winner,
            gap: widget.gap,
            progress: _progress.value,
          ),
        );
      },
    );
  }
}

class _WinningLinePainter extends CustomPainter {
  const _WinningLinePainter({
    required this.winningLine,
    required this.winner,
    required this.gap,
    required this.progress,
  });

  final List<Position> winningLine;
  final Player winner;
  final double gap;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (winningLine.length < 2 || progress <= 0) {
      return;
    }

    final boardSide = math.min(size.width, size.height);
    final origin = Offset(
      (size.width - boardSide) / 2,
      (size.height - boardSide) / 2,
    );
    final cellSide = (boardSide - gap * 2) / 3;
    final startCenter = _cellCenter(winningLine.first, origin, cellSide);
    final endCenter = _cellCenter(winningLine.last, origin, cellSide);
    final segment = endCenter - startCenter;
    final distance = segment.distance;
    if (distance == 0) {
      return;
    }

    final direction = segment / distance;
    final extension = math.min(cellSide * 0.24, 18.0);
    final start = startCenter - direction * extension;
    final end = endCenter + direction * extension;
    final revealedEnd = Offset.lerp(start, end, progress)!;
    final color = winner == Player.x ? AppColors.softCoral : AppColors.teal;
    final strokeWidth = math.min(math.max(cellSide * 0.075, 6.0), 12.0);
    final glowStrength = Curves.easeOut.transform(progress);

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.16 * glowStrength)
      ..strokeWidth = strokeWidth * 3.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth * 1.15);
    final softPaint = Paint()
      ..color = color.withValues(alpha: 0.22 * glowStrength)
      ..strokeWidth = strokeWidth * 1.9
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth * 0.45);
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.95)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas
      ..drawLine(start, revealedEnd, glowPaint)
      ..drawLine(start, revealedEnd, softPaint)
      ..drawLine(start, revealedEnd, linePaint);
  }

  Offset _cellCenter(Position position, Offset origin, double cellSide) {
    return origin +
        Offset(
          position.col * (cellSide + gap) + cellSide / 2,
          position.row * (cellSide + gap) + cellSide / 2,
        );
  }

  @override
  bool shouldRepaint(covariant _WinningLinePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.gap != gap ||
        oldDelegate.winner != winner ||
        oldDelegate.winningLine != winningLine;
  }
}
