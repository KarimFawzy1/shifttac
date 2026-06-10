import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/game/domain/logic/win_checker.dart';
import 'package:shifttac/features/game/domain/models/move.dart';
import 'package:shifttac/features/game/domain/models/player.dart';
import 'package:shifttac/features/game/domain/models/position.dart';

Move _move(Player player, int row, int col, int turnIndex) => Move(
  player: player,
  position: Position(row: row, col: col),
  turnIndex: turnIndex,
);

void main() {
  group('WinChecker.findWinningLine', () {
    test('detects top row win', () {
      final moves = [
        _move(Player.x, 0, 0, 0),
        _move(Player.x, 0, 1, 1),
        _move(Player.x, 0, 2, 2),
      ];

      final line = WinChecker.findWinningLine(
        activeMoves: moves,
        player: Player.x,
      );
      expect(line, const [
        Position(row: 0, col: 0),
        Position(row: 0, col: 1),
        Position(row: 0, col: 2),
      ]);
    });

    test('detects middle row win', () {
      final moves = [
        _move(Player.o, 1, 0, 0),
        _move(Player.o, 1, 1, 1),
        _move(Player.o, 1, 2, 2),
      ];

      final line = WinChecker.findWinningLine(
        activeMoves: moves,
        player: Player.o,
      );
      expect(line, const [
        Position(row: 1, col: 0),
        Position(row: 1, col: 1),
        Position(row: 1, col: 2),
      ]);
    });

    test('detects bottom row win', () {
      final moves = [
        _move(Player.x, 2, 0, 0),
        _move(Player.x, 2, 1, 1),
        _move(Player.x, 2, 2, 2),
      ];

      final line = WinChecker.findWinningLine(
        activeMoves: moves,
        player: Player.x,
      );
      expect(line, const [
        Position(row: 2, col: 0),
        Position(row: 2, col: 1),
        Position(row: 2, col: 2),
      ]);
    });

    test('detects left column win', () {
      final moves = [
        _move(Player.o, 0, 0, 0),
        _move(Player.o, 1, 0, 1),
        _move(Player.o, 2, 0, 2),
      ];

      final line = WinChecker.findWinningLine(
        activeMoves: moves,
        player: Player.o,
      );
      expect(line, const [
        Position(row: 0, col: 0),
        Position(row: 1, col: 0),
        Position(row: 2, col: 0),
      ]);
    });

    test('detects middle column win', () {
      final moves = [
        _move(Player.x, 0, 1, 0),
        _move(Player.x, 1, 1, 1),
        _move(Player.x, 2, 1, 2),
      ];

      final line = WinChecker.findWinningLine(
        activeMoves: moves,
        player: Player.x,
      );
      expect(line, const [
        Position(row: 0, col: 1),
        Position(row: 1, col: 1),
        Position(row: 2, col: 1),
      ]);
    });

    test('detects right column win', () {
      final moves = [
        _move(Player.o, 0, 2, 0),
        _move(Player.o, 1, 2, 1),
        _move(Player.o, 2, 2, 2),
      ];

      final line = WinChecker.findWinningLine(
        activeMoves: moves,
        player: Player.o,
      );
      expect(line, const [
        Position(row: 0, col: 2),
        Position(row: 1, col: 2),
        Position(row: 2, col: 2),
      ]);
    });

    test('detects primary diagonal win', () {
      final moves = [
        _move(Player.x, 0, 0, 0),
        _move(Player.x, 1, 1, 1),
        _move(Player.x, 2, 2, 2),
      ];

      final line = WinChecker.findWinningLine(
        activeMoves: moves,
        player: Player.x,
      );
      expect(line, const [
        Position(row: 0, col: 0),
        Position(row: 1, col: 1),
        Position(row: 2, col: 2),
      ]);
    });

    test('detects secondary diagonal win', () {
      final moves = [
        _move(Player.o, 0, 2, 0),
        _move(Player.o, 1, 1, 1),
        _move(Player.o, 2, 0, 2),
      ];

      final line = WinChecker.findWinningLine(
        activeMoves: moves,
        player: Player.o,
      );
      expect(line, const [
        Position(row: 0, col: 2),
        Position(row: 1, col: 1),
        Position(row: 2, col: 0),
      ]);
    });

    test('returns null for partial line', () {
      final moves = [_move(Player.x, 0, 0, 0), _move(Player.x, 0, 1, 1)];

      final line = WinChecker.findWinningLine(
        activeMoves: moves,
        player: Player.x,
      );
      expect(line, isNull);
    });

    test('returns null for empty board', () {
      final line = WinChecker.findWinningLine(
        activeMoves: const [],
        player: Player.x,
      );
      expect(line, isNull);
    });

    test('uses only the requested player moves', () {
      final moves = [
        _move(Player.x, 0, 0, 0),
        _move(Player.x, 0, 1, 1),
        _move(Player.x, 0, 2, 2),
        _move(Player.o, 1, 0, 3),
        _move(Player.o, 1, 1, 4),
      ];

      final lineForO = WinChecker.findWinningLine(
        activeMoves: moves,
        player: Player.o,
      );
      expect(lineForO, isNull);
    });

    test('tikiCompletionRevealOrder lists columns, rows, then diagonals', () {
      expect(WinChecker.tikiCompletionRevealOrder, hasLength(8));
      expect(WinChecker.tikiCompletionRevealOrder[0], WinChecker.allLines[3]);
      expect(WinChecker.tikiCompletionRevealOrder[1], WinChecker.allLines[4]);
      expect(WinChecker.tikiCompletionRevealOrder[2], WinChecker.allLines[5]);
      expect(WinChecker.tikiCompletionRevealOrder[3], WinChecker.allLines[0]);
      expect(WinChecker.tikiCompletionRevealOrder[4], WinChecker.allLines[1]);
      expect(WinChecker.tikiCompletionRevealOrder[5], WinChecker.allLines[2]);
      expect(WinChecker.tikiCompletionRevealOrder[6], WinChecker.allLines[6]);
      expect(WinChecker.tikiCompletionRevealOrder[7], WinChecker.allLines[7]);
    });

    test('returns an unmodifiable winning line', () {
      final moves = [
        _move(Player.x, 0, 0, 0),
        _move(Player.x, 1, 1, 1),
        _move(Player.x, 2, 2, 2),
      ];

      final line = WinChecker.findWinningLine(
        activeMoves: moves,
        player: Player.x,
      )!;
      expect(
        () => line.add(const Position(row: 1, col: 0)),
        throwsUnsupportedError,
      );
    });
  });
}
