import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/game/domain/models/position.dart';
import 'package:shifttac/shared/widgets/board_winning_line_overlay.dart';

const _horizontalLine = [
  Position(row: 0, col: 0),
  Position(row: 0, col: 1),
  Position(row: 0, col: 2),
];

const _verticalLine = [
  Position(row: 0, col: 0),
  Position(row: 1, col: 0),
  Position(row: 2, col: 0),
];

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(width: 300, height: 300, child: child),
      ),
    ),
  );
}

Future<void> _pumpUntil(
  WidgetTester tester, {
  required bool Function() condition,
  Duration step = const Duration(milliseconds: 50),
  int maxSteps = 40,
}) async {
  for (var stepIndex = 0; stepIndex < maxSteps; stepIndex++) {
    if (condition()) {
      return;
    }
    await tester.pump(step);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BoardWinningLineReveal', () {
    testWidgets('calls onRevealComplete after animation settles', (
      tester,
    ) async {
      var completed = false;

      await tester.pumpWidget(
        _wrap(
          BoardWinningLineReveal(
            winningLine: _horizontalLine,
            color: Colors.red,
            gap: 12,
            onRevealComplete: () => completed = true,
          ),
        ),
      );
      await tester.pump();

      expect(completed, isFalse);

      await _pumpUntil(tester, condition: () => completed);

      expect(completed, isTrue);
    });

    testWidgets('initiallyRevealed does not call onRevealComplete', (
      tester,
    ) async {
      var completed = false;

      await tester.pumpWidget(
        _wrap(
          BoardWinningLineReveal(
            winningLine: _horizontalLine,
            color: Colors.red,
            gap: 12,
            initiallyRevealed: true,
            onRevealComplete: () => completed = true,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(completed, isFalse);
      expect(find.byType(BoardWinningLineReveal), findsOneWidget);
    });
  });

  group('BoardWinningLinesSequenceReveal', () {
    testWidgets('calls onRevealComplete after each line in sequence', (
      tester,
    ) async {
      var completed = false;

      await tester.pumpWidget(
        _wrap(
          BoardWinningLinesSequenceReveal(
            lines: const [_verticalLine, _horizontalLine],
            color: Colors.red,
            gap: 12,
            onRevealComplete: () => completed = true,
          ),
        ),
      );
      await tester.pump();

      expect(completed, isFalse);

      await _pumpUntil(
        tester,
        condition: () => completed,
        maxSteps: 20,
      );
      expect(completed, isFalse);

      await _pumpUntil(tester, condition: () => completed);
      expect(completed, isTrue);
    });
  });
}
