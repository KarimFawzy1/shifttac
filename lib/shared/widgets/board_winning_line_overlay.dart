import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/game/domain/models/position.dart';

const Duration kBoardWinningLineRevealDuration = Duration(milliseconds: 560);
const Duration kBoardWinningLineSettleDuration = Duration(milliseconds: 90);

/// Tiki-Taka first-win line reveal (slower than [kBoardWinningLineRevealDuration]).
const Duration kTikiFirstWinLineRevealDuration = Duration(milliseconds: 780);
const Duration kTikiFirstWinLineSettleDuration = Duration(milliseconds: 120);

/// Tiki-Taka full-board completion sequence (faster per line).
const Duration kTikiCompletionLineRevealDuration = Duration(milliseconds: 280);
const Duration kTikiCompletionLineSettleDuration = Duration(milliseconds: 40);

/// Extra winning-line length beyond the default cell overhang (8 logical px total).
const double kBoardWinningLineLengthExtra = 40.0;

/// Animated reveal of a single 3-in-a-row line on a square 3×3 board.
class BoardWinningLineReveal extends StatefulWidget {
  const BoardWinningLineReveal({
    super.key,
    required this.winningLine,
    required this.color,
    required this.gap,
    this.revealDuration = kBoardWinningLineRevealDuration,
    this.settleDuration = kBoardWinningLineSettleDuration,
    this.onRevealComplete,
    this.initiallyRevealed = false,
  });

  final List<Position> winningLine;
  final Color color;
  final double gap;
  final Duration revealDuration;
  final Duration settleDuration;
  final VoidCallback? onRevealComplete;

  /// When true, the line is drawn at full progress without animating or
  /// calling [onRevealComplete] (e.g. first-win line during continue play).
  final bool initiallyRevealed;

  @override
  State<BoardWinningLineReveal> createState() => _BoardWinningLineRevealState();
}

class _BoardWinningLineRevealState extends State<BoardWinningLineReveal>
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
      duration: widget.revealDuration,
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _startRevealIfNeeded();
  }

  @override
  void didUpdateWidget(covariant BoardWinningLineReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revealDuration != widget.revealDuration) {
      _controller.duration = widget.revealDuration;
    }
    _startRevealIfNeeded();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startRevealIfNeeded() {
    final lineKey = boardWinningLineKey(widget.winningLine);
    if (lineKey == _revealedLineKey) {
      return;
    }

    _revealedLineKey = lineKey;
    _completionReported = false;

    if (widget.initiallyRevealed) {
      _controller.value = 1;
      return;
    }

    unawaited(_playReveal());
  }

  Future<void> _playReveal() async {
    try {
      await _controller.forward(from: 0).orCancel;
      await Future<void>.delayed(widget.settleDuration);
    } catch (_) {
      return;
    }

    if (!mounted || _completionReported || widget.initiallyRevealed) {
      return;
    }

    _completionReported = true;
    widget.onRevealComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        return CustomPaint(
          painter: BoardWinningLinePainter(
            winningLine: widget.winningLine,
            color: widget.color,
            gap: widget.gap,
            progress: _progress.value,
          ),
        );
      },
    );
  }
}

/// Reveals multiple lines one after another; completed lines stay visible.
class BoardWinningLinesSequenceReveal extends StatefulWidget {
  const BoardWinningLinesSequenceReveal({
    super.key,
    required this.lines,
    required this.color,
    required this.gap,
    this.revealDuration = kBoardWinningLineRevealDuration,
    this.settleDuration = kBoardWinningLineSettleDuration,
    this.onRevealComplete,
  });

  final List<List<Position>> lines;
  final Color color;
  final double gap;
  final Duration revealDuration;
  final Duration settleDuration;
  final VoidCallback? onRevealComplete;

  @override
  State<BoardWinningLinesSequenceReveal> createState() =>
      _BoardWinningLinesSequenceRevealState();
}

class _BoardWinningLinesSequenceRevealState
    extends State<BoardWinningLinesSequenceReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  int _activeLineIndex = 0;
  bool _completionReported = false;
  String? _sequenceKey;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.revealDuration,
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _startSequenceIfNeeded();
  }

  @override
  void didUpdateWidget(covariant BoardWinningLinesSequenceReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revealDuration != widget.revealDuration) {
      _controller.duration = widget.revealDuration;
    }
    _startSequenceIfNeeded();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _buildSequenceKey() {
    return widget.lines.map(boardWinningLineKey).join('|');
  }

  void _startSequenceIfNeeded() {
    final key = _buildSequenceKey();
    if (key == _sequenceKey) {
      return;
    }

    _sequenceKey = key;
    _activeLineIndex = 0;
    _completionReported = false;
    unawaited(_playSequence());
  }

  Future<void> _playSequence() async {
    if (widget.lines.isEmpty) {
      _reportComplete();
      return;
    }

    for (var index = 0; index < widget.lines.length; index++) {
      if (!mounted || _sequenceKey != _buildSequenceKey()) {
        return;
      }

      setState(() => _activeLineIndex = index);
      try {
        await _controller.forward(from: 0).orCancel;
        await Future<void>.delayed(widget.settleDuration);
      } catch (_) {
        return;
      }
    }

    _reportComplete();
  }

  void _reportComplete() {
    if (!mounted || _completionReported) {
      return;
    }

    _completionReported = true;
    widget.onRevealComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        return CustomPaint(
          painter: _BoardWinningLinesSequencePainter(
            lines: widget.lines,
            color: widget.color,
            gap: widget.gap,
            activeLineIndex: _activeLineIndex,
            activeProgress: _progress.value,
          ),
        );
      },
    );
  }
}

class BoardWinningLinePainter extends CustomPainter {
  const BoardWinningLinePainter({
    required this.winningLine,
    required this.color,
    required this.gap,
    required this.progress,
  });

  final List<Position> winningLine;
  final Color color;
  final double gap;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    _paintLine(
      canvas: canvas,
      size: size,
      winningLine: winningLine,
      color: color,
      gap: gap,
      progress: progress,
    );
  }

  static void _paintLine({
    required Canvas canvas,
    required Size size,
    required List<Position> winningLine,
    required Color color,
    required double gap,
    required double progress,
  }) {
    if (winningLine.length < 2 || progress <= 0) {
      return;
    }

    final boardSide = math.min(size.width, size.height);
    final origin = Offset(
      (size.width - boardSide) / 2,
      (size.height - boardSide) / 2,
    );
    final cellSide = (boardSide - gap * 2) / 3;
    final startCenter = _cellCenter(winningLine.first, origin, cellSide, gap);
    final endCenter = _cellCenter(winningLine.last, origin, cellSide, gap);
    final segment = endCenter - startCenter;
    final distance = segment.distance;
    if (distance == 0) {
      return;
    }

    final direction = segment / distance;
    final extension =
        math.min(cellSide * 0.24, 18.0) + kBoardWinningLineLengthExtra / 2;
    final start = startCenter - direction * extension;
    final end = endCenter + direction * extension;
    final revealedEnd = Offset.lerp(start, end, progress)!;
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

  static Offset _cellCenter(
    Position position,
    Offset origin,
    double cellSide,
    double gap,
  ) {
    return origin +
        Offset(
          position.col * (cellSide + gap) + cellSide / 2,
          position.row * (cellSide + gap) + cellSide / 2,
        );
  }

  @override
  bool shouldRepaint(covariant BoardWinningLinePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.gap != gap ||
        oldDelegate.color != color ||
        oldDelegate.winningLine != winningLine;
  }
}

class _BoardWinningLinesSequencePainter extends CustomPainter {
  const _BoardWinningLinesSequencePainter({
    required this.lines,
    required this.color,
    required this.gap,
    required this.activeLineIndex,
    required this.activeProgress,
  });

  final List<List<Position>> lines;
  final Color color;
  final double gap;
  final int activeLineIndex;
  final double activeProgress;

  @override
  void paint(Canvas canvas, Size size) {
    for (var index = 0; index < lines.length; index++) {
      if (index > activeLineIndex) {
        break;
      }

      final progress = index < activeLineIndex ? 1.0 : activeProgress;
      BoardWinningLinePainter._paintLine(
        canvas: canvas,
        size: size,
        winningLine: lines[index],
        color: color,
        gap: gap,
        progress: progress,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BoardWinningLinesSequencePainter oldDelegate) {
    return oldDelegate.activeLineIndex != activeLineIndex ||
        oldDelegate.activeProgress != activeProgress ||
        oldDelegate.gap != gap ||
        oldDelegate.color != color ||
        oldDelegate.lines != lines;
  }
}

String boardWinningLineKey(List<Position> line) {
  return line.map((position) => position.index).join('-');
}
