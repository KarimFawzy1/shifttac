import 'package:fake_async/fake_async.dart'; // ignore: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/constants/game_constants.dart';
import 'package:shifttac/features/game/domain/models/game_status.dart';
import 'package:shifttac/features/game/domain/models/player.dart';
import 'package:shifttac/features/game/domain/models/position.dart';
import 'package:shifttac/features/game/presentation/state/game_cubit.dart';
import 'package:shifttac/features/game/presentation/state/game_state.dart';

void main() {
  group('GameCubit', () {
    test('initial state matches GameState.initial()', () {
      final cubit = GameCubit();
      addTearDown(cubit.close);

      final expected = GameState.initial();
      expect(cubit.state.snapshot.turnIndex, expected.snapshot.turnIndex);
      expect(
        cubit.state.snapshot.currentPlayer,
        expected.snapshot.currentPlayer,
      );
      expect(cubit.state.snapshot.status, expected.snapshot.status);
      expect(cubit.state.inputLocked, isFalse);
      expect(cubit.state.lastPlacedPosition, isNull);
      expect(cubit.state.lastRemovedPosition, isNull);
      expect(cubit.state.matchDurationMs, 0);
    });

    test('tap on empty cell emits new snapshot and lastPlacedPosition', () {
      final cubit = GameCubit();
      addTearDown(cubit.close);

      final before = cubit.state.snapshot;
      cubit.onCellTapped(const Position(row: 0, col: 0));

      expect(identical(cubit.state.snapshot, before), isFalse);
      expect(cubit.state.snapshot.turnIndex, 1);
      expect(cubit.state.snapshot.currentPlayer, Player.o);
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
        expect(cubit.state.snapshot.currentPlayer, Player.x);
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

    test('restart returns to initial snapshot and clears lock', () {
      fakeAsync((async) {
        final cubit = GameCubit();

        cubit.onCellTapped(const Position(row: 1, col: 1));
        expect(cubit.state.inputLocked, isTrue);

        cubit.restart();

        expect(cubit.state.snapshot.turnIndex, 0);
        expect(cubit.state.snapshot.currentPlayer, Player.x);
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
