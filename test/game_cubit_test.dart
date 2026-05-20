import 'package:fake_async/fake_async.dart'; // ignore: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/constants/game_constants.dart';
import 'package:shifttac/features/game/domain/models/game_status.dart';
import 'package:shifttac/features/game/domain/models/player.dart';
import 'package:shifttac/features/game/domain/models/position.dart';
import 'package:shifttac/features/game/presentation/state/game_cubit.dart';

void main() {
  group('GameCubit', () {
    test('initial state matches GameState.initial()', () {
      final cubit = GameCubit();
      addTearDown(cubit.close);

      expect(cubit.state.snapshot.turnIndex, 0);
      expect(
        [Player.x, Player.o],
        contains(cubit.state.snapshot.currentPlayer),
      );
      expect(cubit.state.snapshot.status, GameStatus.playing);
      expect(cubit.state.inputLocked, isFalse);
      expect(cubit.state.lastPlacedPosition, isNull);
      expect(cubit.state.lastRemovedPosition, isNull);
      expect(cubit.state.matchDurationMs, greaterThanOrEqualTo(0));
    });

    test('tap on empty cell emits new snapshot and lastPlacedPosition', () {
      final cubit = GameCubit();
      addTearDown(cubit.close);

      final before = cubit.state.snapshot;
      final starter = before.currentPlayer;
      cubit.onCellTapped(const Position(row: 0, col: 0));

      expect(identical(cubit.state.snapshot, before), isFalse);
      expect(cubit.state.snapshot.turnIndex, 1);
      expect(cubit.state.snapshot.currentPlayer, starter.opponent);
      expect(cubit.state.lastPlacedPosition, const Position(row: 0, col: 0));
      expect(cubit.state.inputLocked, isTrue);
    });

    test('tap on occupied cell is no-op when unlocked', () {
      fakeAsync((async) {
        final cubit = GameCubit();

        cubit.onCellTapped(const Position(row: 0, col: 0));
        async.elapse(Duration(milliseconds: GameConstants.inputLockMs));

        final snap = cubit.state.snapshot;
        cubit.onCellTapped(const Position(row: 0, col: 0));

        expect(identical(cubit.state.snapshot, snap), isTrue);
        expect(cubit.state.snapshot.turnIndex, snap.turnIndex);
        cubit.close();
      });
    });

    test('ten rapid taps on same cell produce exactly one state change', () {
      fakeAsync((async) {
        final cubit = GameCubit();

        for (var i = 0; i < 10; i++) {
          cubit.onCellTapped(const Position(row: 0, col: 0));
        }

        expect(cubit.state.snapshot.turnIndex, 1);
        expect(cubit.state.lastPlacedPosition, const Position(row: 0, col: 0));
        expect(cubit.state.inputLocked, isTrue);
        cubit.close();
      });
    });

    test('rapid taps while input locked do not apply a second move', () {
      fakeAsync((async) {
        final cubit = GameCubit();

        cubit.onCellTapped(const Position(row: 0, col: 0));
        final afterFirst = cubit.state.snapshot;

        cubit.onCellTapped(const Position(row: 1, col: 1));

        expect(identical(cubit.state.snapshot, afterFirst), isTrue);
        expect(cubit.state.snapshot.turnIndex, 1);

        async.elapse(Duration(milliseconds: GameConstants.inputLockMs));

        cubit.onCellTapped(const Position(row: 1, col: 1));
        expect(cubit.state.snapshot.turnIndex, 2);
        expect(cubit.state.snapshot.currentPlayer, afterFirst.currentPlayer.opponent);
        cubit.close();
      });
    });

    test('input lock clears after inputLockMs', () {
      fakeAsync((async) {
        final cubit = GameCubit();

        cubit.onCellTapped(const Position(row: 2, col: 2));
        expect(cubit.state.inputLocked, isTrue);

        async.elapse(Duration(milliseconds: GameConstants.inputLockMs - 1));
        expect(cubit.state.inputLocked, isTrue);

        async.elapse(const Duration(milliseconds: 1));
        expect(cubit.state.inputLocked, isFalse);
        cubit.close();
      });
    });

    test('restart during input lock clears markers and ignores stale unlock', () {
      fakeAsync((async) {
        final cubit = GameCubit();

        cubit.onCellTapped(const Position(row: 0, col: 0));
        expect(cubit.state.inputLocked, isTrue);
        expect(cubit.state.lastPlacedPosition, isNotNull);

        cubit.restart();

        expect(cubit.state.inputLocked, isFalse);
        expect(cubit.state.lastPlacedPosition, isNull);
        expect(cubit.state.lastRemovedPosition, isNull);
        expect(cubit.state.snapshot.turnIndex, 0);

        async.elapse(Duration(milliseconds: GameConstants.inputLockMs * 2));
        expect(cubit.state.inputLocked, isFalse);
        expect(cubit.state.snapshot.turnIndex, 0);
        cubit.close();
      });
    });

    test(
      'restart during fade-out markers leaves empty board with no ghost marks',
      () {
        fakeAsync((async) {
          final cubit = GameCubit();
          void unlock() =>
              async.elapse(Duration(milliseconds: GameConstants.inputLockMs));

          cubit.onCellTapped(const Position(row: 0, col: 0));
          unlock();
          cubit.onCellTapped(const Position(row: 2, col: 2));
          unlock();
          cubit.onCellTapped(const Position(row: 0, col: 1));
          unlock();
          cubit.onCellTapped(const Position(row: 1, col: 2));
          unlock();
          cubit.onCellTapped(const Position(row: 2, col: 0));
          unlock();
          cubit.onCellTapped(const Position(row: 1, col: 1));
          unlock();
          cubit.onCellTapped(const Position(row: 0, col: 2));

          expect(cubit.state.lastRemovedPosition, const Position(row: 0, col: 0));
          expect(cubit.state.inputLocked, isTrue);

          cubit.restart();

          expect(cubit.state.lastPlacedPosition, isNull);
          expect(cubit.state.lastRemovedPosition, isNull);
          expect(cubit.state.snapshot.xMoves, isEmpty);
          expect(cubit.state.snapshot.oMoves, isEmpty);
          unlock();
          expect(cubit.state.snapshot.xMoves, isEmpty);
          cubit.close();
        });
      },
    );

    test('tap while match is not playing is rejected', () {
      fakeAsync((async) {
        final cubit = GameCubit();
        void unlock() =>
            async.elapse(Duration(milliseconds: GameConstants.inputLockMs));

        for (var i = 0; i < 5; i++) {
          cubit.onCellTapped(Position(row: i % 3, col: 0));
          unlock();
          cubit.onCellTapped(Position(row: i % 3, col: 1));
          unlock();
          cubit.onCellTapped(Position(row: i % 3, col: 2));
          unlock();
        }

        expect(cubit.state.snapshot.status, GameStatus.won);
        final snap = cubit.state.snapshot;
        expect(
          cubit.onCellTapped(const Position(row: 0, col: 0)),
          CellTapResult.rejectedNotPlaying,
        );
        expect(identical(cubit.state.snapshot, snap), isTrue);
        cubit.close();
      });
    });

    test('restart returns to initial snapshot and clears lock', () {
      fakeAsync((async) {
        final cubit = GameCubit();

        cubit.onCellTapped(const Position(row: 1, col: 1));
        expect(cubit.state.inputLocked, isTrue);

        cubit.restart();

        expect(cubit.state.snapshot.turnIndex, 0);
        expect(
          [Player.x, Player.o],
          contains(cubit.state.snapshot.currentPlayer),
        );
        expect(cubit.state.snapshot.status, GameStatus.playing);
        expect(cubit.state.inputLocked, isFalse);
        expect(cubit.state.lastPlacedPosition, isNull);
        expect(cubit.state.lastRemovedPosition, isNull);
        expect(cubit.state.matchDurationMs, 0);

        async.elapse(Duration(milliseconds: GameConstants.inputLockMs));
        expect(cubit.state.inputLocked, isFalse);
        expect(cubit.state.snapshot.turnIndex, 0);
        cubit.close();
      });
    });

    test(
      'onAppBackgrounded pauses match and requests pause sheet on resume',
      () {
        final cubit = GameCubit();
        addTearDown(cubit.close);

        expect(cubit.shouldPresentPauseAfterBackground, isFalse);

        cubit.onAppBackgrounded();

        expect(cubit.shouldPresentPauseAfterBackground, isTrue);

        cubit.clearPauseSheetRequestForBackground();
        expect(cubit.shouldPresentPauseAfterBackground, isFalse);

        cubit.resumeMatch();
        cubit.onAppBackgrounded();
        expect(cubit.shouldPresentPauseAfterBackground, isTrue);
      },
    );

    test('onAppBackgrounded is no-op when match is not playing', () {
      fakeAsync((async) {
        final cubit = GameCubit();
        void unlock() =>
            async.elapse(Duration(milliseconds: GameConstants.inputLockMs));

        for (var i = 0; i < 5; i++) {
          cubit.onCellTapped(Position(row: i % 3, col: 0));
          unlock();
          cubit.onCellTapped(Position(row: i % 3, col: 1));
          unlock();
          cubit.onCellTapped(Position(row: i % 3, col: 2));
          unlock();
        }

        expect(cubit.state.snapshot.status, GameStatus.won);
        cubit.onAppBackgrounded();
        expect(cubit.shouldPresentPauseAfterBackground, isFalse);
        cubit.close();
      });
    });

    test('pauseMatch stops match duration from advancing', () async {
      final cubit = GameCubit();

      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final elapsedBeforePause = cubit.state.matchDurationMs;
      expect(elapsedBeforePause, greaterThan(0));

      cubit.pauseMatch();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(cubit.state.matchDurationMs, elapsedBeforePause);

      cubit.resumeMatch();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(cubit.state.matchDurationMs, greaterThan(elapsedBeforePause));
      await cubit.close();
    });

    test('clearLastEventMarkers clears placement markers only', () {
      fakeAsync((async) {
        final cubit = GameCubit();
        void unlock() =>
            async.elapse(Duration(milliseconds: GameConstants.inputLockMs));

        cubit.onCellTapped(const Position(row: 0, col: 0));
        unlock();
        cubit.onCellTapped(const Position(row: 2, col: 2));
        unlock();
        cubit.onCellTapped(const Position(row: 0, col: 1));
        unlock();
        cubit.onCellTapped(const Position(row: 1, col: 2));
        unlock();
        cubit.onCellTapped(const Position(row: 2, col: 0));
        unlock();
        cubit.onCellTapped(const Position(row: 1, col: 1));
        unlock();
        cubit.onCellTapped(const Position(row: 0, col: 2));

        expect(cubit.state.lastRemovedPosition, const Position(row: 0, col: 0));
        expect(cubit.state.lastPlacedPosition, const Position(row: 0, col: 2));

        final snapBefore = cubit.state.snapshot;
        cubit.clearLastEventMarkers();

        expect(cubit.state.lastPlacedPosition, isNull);
        expect(cubit.state.lastRemovedPosition, isNull);
        expect(identical(cubit.state.snapshot, snapBefore), isTrue);
        cubit.close();
      });
    });
  });
}
