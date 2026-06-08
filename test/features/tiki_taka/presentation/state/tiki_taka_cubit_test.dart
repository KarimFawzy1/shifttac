import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/tiki_taka/data/local/daos/board_dao.dart';
import 'package:shifttac/features/tiki_taka/data/local/daos/validation_dao.dart';
import 'package:shifttac/features/tiki_taka/data/models/tiki_board.dart';
import 'package:shifttac/features/tiki_taka/data/models/tiki_player_search_result.dart';
import 'package:shifttac/features/tiki_taka/domain/logic/tiki_taka_game_engine.dart';
import 'package:shifttac/features/tiki_taka/domain/models/tiki_game_state.dart';
import 'package:shifttac/features/tiki_taka/domain/models/tiki_game_status.dart';
import 'package:shifttac/features/tiki_taka/presentation/state/tiki_taka_cubit.dart';
import 'package:shifttac/features/tiki_taka/presentation/state/tiki_taka_state.dart';

import '../../data/local/tiki_taka_dao_test_support.dart';

TikiTakaDependencies _dependencies(TikiTakaTestDatabaseHandle handle) {
  return tikiTakaTestDependencies(handle);
}

TikiTakaCubit _createCubit(TikiTakaTestDatabaseHandle handle) {
  return TikiTakaCubit(dependencies: _dependencies(handle));
}

Future<(int row, int col, TikiPlayerSearchResult player)?> _findAnyValidCell({
  required TikiTakaTestDatabaseHandle databaseHandle,
  required TikiBoard board,
}) async {
  for (var row = 0; row < 3; row++) {
    for (var col = 0; col < 3; col++) {
      final player = await _findValidPlayer(
        databaseHandle: databaseHandle,
        board: board,
        row: row,
        col: col,
      );
      if (player != null) {
        return (row, col, player);
      }
    }
  }
  return null;
}

Future<(int row, int col, TikiPlayerSearchResult player)?>
_findInvalidCellForPlayer({
  required ValidationDao validationDao,
  required TikiBoard board,
  required TikiPlayerSearchResult player,
}) async {
  for (var row = 0; row < 3; row++) {
    for (var col = 0; col < 3; col++) {
      final match = await validationDao.validatePlayer(
        playerId: player.id,
        rowAttributeId: board.rowAttributes[row].id,
        colAttributeId: board.columnAttributes[col].id,
      );
      if (match == null) {
        return (row, col, player);
      }
    }
  }
  return null;
}

Future<TikiPlayerSearchResult?> _findValidPlayer({
  required TikiTakaTestDatabaseHandle databaseHandle,
  required TikiBoard board,
  required int row,
  required int col,
  Set<String> excludePlayerIds = const {},
}) async {
  final matches = await databaseHandle.database.rawQuery(
    '''
    SELECT DISTINCT p.id, p.display_name, p.position, p.nation
    FROM players p
    INNER JOIN player_attributes a
      ON a.player_id = p.id AND a.attribute_id = ?
    INNER JOIN player_attributes b
      ON b.player_id = p.id AND b.attribute_id = ?
    LIMIT 20
    ''',
    [board.rowAttributes[row].id, board.columnAttributes[col].id],
  );

  for (final match in matches) {
    final player = TikiPlayerSearchResult.fromMap(match);
    if (!excludePlayerIds.contains(player.id)) {
      return player;
    }
  }

  return null;
}

void main() {
  late TikiTakaTestDatabaseHandle handle;

  setUpAll(ensureTikiTakaDaoTestInit);

  setUp(() async {
    handle = await openTikiTakaTestDatabase();
  });

  tearDown(() async {
    await handle.close();
  });

  group('TikiTakaCubit', () {
    test('loadBoard exposes a playable board with row and column headers', () async {
      final cubit = _createCubit(handle);
      addTearDown(cubit.close);

      await cubit.loadBoard();

      expect(cubit.state.status, TikiGameStatus.ongoing);
      expect(cubit.state.rowHeaders, hasLength(3));
      expect(cubit.state.columnHeaders, hasLength(3));
      expect(
        cubit.state.rowHeaders.map((attribute) => attribute.id).toSet(),
        hasLength(3),
      );
      expect(
        cubit.state.columnHeaders.map((attribute) => attribute.id).toSet(),
        hasLength(3),
      );
      final headerIds = {
        ...cubit.state.rowHeaders.map((attribute) => attribute.id),
        ...cubit.state.columnHeaders.map((attribute) => attribute.id),
      };
      expect(headerIds, hasLength(6));
      expect(cubit.state.game.cells, hasLength(9));
      expect(cubit.state.hearts, TikiGameState.startingHearts);
    });

    test('timer starts after board load', () async {
      final cubit = _createCubit(handle);
      addTearDown(cubit.close);

      await cubit.loadBoard();

      await Future<void>.delayed(const Duration(milliseconds: 1100));

      expect(cubit.state.elapsedMs, greaterThanOrEqualTo(1000));
    });

    test('timer stops on exit and lost', () async {
      final cubit = _createCubit(handle);
      addTearDown(cubit.close);
      final validationDao = ValidationDao(handle.database);

      await cubit.loadBoard();
      await Future<void>.delayed(const Duration(milliseconds: 500));

      cubit.exitMatch();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(cubit.state.elapsedMs, 0);

      await cubit.loadBoard();
      final board = cubit.state.game.board!;
      final validCell = await _findAnyValidCell(
        databaseHandle: handle,
        board: board,
      );
      expect(validCell, isNotNull);

      final invalidCell = await _findInvalidCellForPlayer(
        validationDao: validationDao,
        board: board,
        player: validCell!.$3,
      );
      expect(invalidCell, isNotNull);

      for (var i = 0; i < 5; i++) {
        cubit.onCellTapped(invalidCell!.$1, invalidCell.$2);
        await cubit.selectPlayer(invalidCell.$3);
      }

      expect(cubit.state.status, TikiGameStatus.lost);
      final elapsedAtLoss = cubit.state.elapsedMs;
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(cubit.state.elapsedMs, elapsedAtLoss);
    });

    test('timer keeps running during firstWin and after continue', () async {
      final cubit = _createCubit(handle);
      addTearDown(cubit.close);
      await cubit.loadBoard();
      final board = cubit.state.game.board!;
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final rowPlayers = <TikiPlayerSearchResult>[];
      for (var col = 0; col < 3; col++) {
        final player = await _findValidPlayer(
          databaseHandle: handle,
          board: board,
          row: 0,
          col: col,
          excludePlayerIds: rowPlayers.map((item) => item.id).toSet(),
        );
        expect(player, isNotNull);
        rowPlayers.add(player!);
      }

      for (var col = 0; col < 3; col++) {
        cubit.onCellTapped(0, col);
        await cubit.selectPlayer(rowPlayers[col]);
      }

      expect(cubit.state.status, TikiGameStatus.firstWin);
      final elapsedAtFirstWin = cubit.state.elapsedMs;

      await Future<void>.delayed(const Duration(milliseconds: 1100));
      cubit.refreshElapsedForTest();
      expect(cubit.state.elapsedMs, greaterThan(elapsedAtFirstWin));

      cubit.continueAfterFirstWin();
      expect(cubit.state.status, TikiGameStatus.continuing);

      await Future<void>.delayed(const Duration(milliseconds: 1100));
      cubit.refreshElapsedForTest();
      expect(cubit.state.elapsedMs, greaterThan(elapsedAtFirstWin));
    });

    test('pauseTimer and resumeTimer control elapsed updates', () async {
      final cubit = _createCubit(handle);
      addTearDown(cubit.close);

      await cubit.loadBoard();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      cubit.refreshElapsedForTest();

      cubit.pauseTimer();
      final elapsedPaused = cubit.state.elapsedMs;
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(cubit.state.elapsedMs, elapsedPaused);

      cubit.resumeTimer();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      cubit.refreshElapsedForTest();
      expect(cubit.state.elapsedMs, greaterThan(elapsedPaused));
    });

    test('valid selection fills cell through state', () async {
      final cubit = _createCubit(handle);
      addTearDown(cubit.close);
      await cubit.loadBoard();

      final board = cubit.state.game.board!;
      final cell = await _findAnyValidCell(
        databaseHandle: handle,
        board: board,
      );
      expect(cell, isNotNull);

      expect(
        cubit.onCellTapped(cell!.$1, cell.$2),
        TikiCellTapResult.openedSearch,
      );

      final result = await cubit.selectPlayer(cell.$3);

      expect(result, TikiSelectPlayerResult.accepted);
      expect(
        cubit.state.game.cellAt(cell.$1, cell.$2).player?.displayName,
        cell.$3.displayName,
      );
      expect(cubit.state.activeCell, isNull);
      expect(cubit.state.game.usedPlayerIds, contains(cell.$3.id));
    });

    test('invalid selection reduces hearts through state', () async {
      final cubit = _createCubit(handle);
      addTearDown(cubit.close);
      await cubit.loadBoard();

      final board = cubit.state.game.board!;
      final validCell = await _findAnyValidCell(
        databaseHandle: handle,
        board: board,
      );
      expect(validCell, isNotNull);

      final invalidCell = await _findInvalidCellForPlayer(
        validationDao: ValidationDao(handle.database),
        board: board,
        player: validCell!.$3,
      );
      expect(invalidCell, isNotNull);

      cubit.onCellTapped(invalidCell!.$1, invalidCell.$2);
      final result = await cubit.selectPlayer(invalidCell.$3);

      expect(result, TikiSelectPlayerResult.rejectedInvalid);
      expect(cubit.state.hearts, 4);
      expect(
        cubit.state.game.cellAt(invalidCell.$1, invalidCell.$2).isEmpty,
        isTrue,
      );
    });

    test('duplicate correct player keeps hearts', () async {
      final cubit = _createCubit(handle);
      addTearDown(cubit.close);
      await cubit.loadBoard();

      final board = cubit.state.game.board!;
      const salah = TikiPlayerSearchResult(
        id: 'tm:148455',
        displayName: 'Mohamed Salah',
      );
      final validationDao = ValidationDao(handle.database);

      (int, int)? firstCell;
      (int, int)? secondCell;
      for (var row = 0; row < 3; row++) {
        for (var col = 0; col < 3; col++) {
          final match = await validationDao.validatePlayer(
            playerId: salah.id,
            rowAttributeId: board.rowAttributes[row].id,
            colAttributeId: board.columnAttributes[col].id,
          );
          if (match == null) {
            continue;
          }

          final coordinates = (row, col);
          if (firstCell == null) {
            firstCell = coordinates;
          } else if (firstCell != coordinates) {
            secondCell = coordinates;
            break;
          }
        }
        if (secondCell != null) {
          break;
        }
      }

      if (secondCell == null) {
        return;
      }

      cubit.onCellTapped(firstCell!.$1, firstCell.$2);
      await cubit.selectPlayer(salah);
      expect(cubit.state.hearts, 5);

      cubit.onCellTapped(secondCell.$1, secondCell.$2);
      final result = await cubit.selectPlayer(salah);

      expect(result, TikiSelectPlayerResult.rejectedDuplicatePlayer);
      expect(cubit.state.hearts, 5);
      expect(
        cubit.state.game.cellAt(secondCell.$1, secondCell.$2).isEmpty,
        isTrue,
      );
    });

    test('duplicate wrong selection reduces hearts through state', () async {
      final cubit = _createCubit(handle);
      addTearDown(cubit.close);
      await cubit.loadBoard();

      final board = cubit.state.game.board!;
      final cell = await _findAnyValidCell(
        databaseHandle: handle,
        board: board,
      );
      expect(cell, isNotNull);

      cubit.onCellTapped(cell!.$1, cell.$2);
      await cubit.selectPlayer(cell.$3);
      expect(cubit.state.game.usedPlayerIds, contains(cell.$3.id));

      final wrongCell = await _findInvalidCellForPlayer(
        validationDao: ValidationDao(handle.database),
        board: board,
        player: cell.$3,
      );
      expect(wrongCell, isNotNull);

      cubit.onCellTapped(wrongCell!.$1, wrongCell.$2);
      final result = await cubit.selectPlayer(cell.$3);

      expect(result, TikiSelectPlayerResult.rejectedInvalid);
      expect(cubit.state.hearts, 4);
      expect(cubit.state.game.cellAt(wrongCell.$1, wrongCell.$2).isEmpty, isTrue);
    });

    test('first win is reached through valid selections', () async {
      final cubit = _createCubit(handle);
      addTearDown(cubit.close);
      await cubit.loadBoard();
      final board = cubit.state.game.board!;

      for (var col = 0; col < 3; col++) {
        final player = await _findValidPlayer(
          databaseHandle: handle,
          board: board,
          row: 0,
          col: col,
          excludePlayerIds: cubit.state.game.usedPlayerIds,
        );
        expect(player, isNotNull);

        cubit.onCellTapped(0, col);
        final result = await cubit.selectPlayer(player!);
        expect(result, TikiSelectPlayerResult.accepted);
      }

      expect(cubit.state.status, TikiGameStatus.firstWin);
      expect(cubit.state.game.filledCellCount, 3);
    });

    test('completed is reached after continue and filling the board', () async {
      final cubit = _createCubit(handle);
      addTearDown(cubit.close);
      await cubit.loadBoard();
      final board = cubit.state.game.board!;

      for (var col = 0; col < 3; col++) {
        final player = await _findValidPlayer(
          databaseHandle: handle,
          board: board,
          row: 0,
          col: col,
          excludePlayerIds: cubit.state.game.usedPlayerIds,
        );
        expect(player, isNotNull);
        cubit.onCellTapped(0, col);
        final result = await cubit.selectPlayer(player!);
        expect(result, TikiSelectPlayerResult.accepted);
      }

      expect(cubit.state.status, TikiGameStatus.firstWin);
      cubit.continueAfterFirstWin();
      expect(cubit.state.status, TikiGameStatus.continuing);

      final loadedBoard = board;
      for (var row = 0; row < 3; row++) {
        for (var col = 0; col < 3; col++) {
          if (cubit.state.game.cellAt(row, col).isFilled) {
            continue;
          }

          final player = await _findValidPlayer(
            databaseHandle: handle,
            board: loadedBoard,
            row: row,
            col: col,
            excludePlayerIds: cubit.state.game.usedPlayerIds,
          );
          expect(
            player,
            isNotNull,
            reason: 'Expected a valid player for row $row col $col',
          );

          cubit.onCellTapped(row, col);
          final result = await cubit.selectPlayer(player!);
          expect(result, TikiSelectPlayerResult.accepted);
        }
      }

      expect(cubit.state.status, TikiGameStatus.completed);
      expect(cubit.state.game.filledCellCount, 9);
    });

    test('restart loads a fresh random board', () async {
      final cubit = _createCubit(handle);
      addTearDown(cubit.close);
      await cubit.loadBoard();
      final firstSignature = [
        ...cubit.state.rowHeaders.map((attribute) => attribute.id),
        ...cubit.state.columnHeaders.map((attribute) => attribute.id),
      ];

      var foundDifferent = false;
      for (var attempt = 0; attempt < 12; attempt++) {
        await cubit.restart();
        final nextSignature = [
          ...cubit.state.rowHeaders.map((attribute) => attribute.id),
          ...cubit.state.columnHeaders.map((attribute) => attribute.id),
        ];
        if (!listEquals(firstSignature, nextSignature)) {
          foundDifferent = true;
          break;
        }
      }

      expect(foundDifferent, isTrue);
    });

    test('clearBoard clears cells and used players without reloading board',
        () async {
      final cubit = _createCubit(handle);
      addTearDown(cubit.close);

      await cubit.loadBoard();
      final boardBeforeClear = cubit.state.game.board;

      final board = cubit.state.game.board!;
      final cell = await _findAnyValidCell(
        databaseHandle: handle,
        board: board,
      );
      expect(cell, isNotNull);

      cubit.onCellTapped(cell!.$1, cell.$2);
      await cubit.selectPlayer(cell.$3);
      expect(cubit.state.game.filledCellCount, 1);
      expect(cubit.state.canClearBoard, isTrue);

      cubit.clearBoard();

      expect(cubit.state.game.board, boardBeforeClear);
      expect(cubit.state.game.usedPlayerIds, isEmpty);
      expect(cubit.state.game.filledCellCount, 0);
      expect(cubit.state.canClearBoard, isFalse);
      expect(cubit.state.activeCell, isNull);
    });

    test('restart clears cells, used players, timer, and hearts', () async {
      final cubit = _createCubit(handle);
      addTearDown(cubit.close);

      await cubit.loadBoard();
      await Future<void>.delayed(const Duration(milliseconds: 1500));

      final board = cubit.state.game.board!;
      final cell = await _findAnyValidCell(
        databaseHandle: handle,
        board: board,
      );
      expect(cell, isNotNull);

      cubit.onCellTapped(cell!.$1, cell.$2);
      await cubit.selectPlayer(cell.$3);
      expect(cubit.state.game.filledCellCount, 1);

      await cubit.restart();

      expect(cubit.state.hearts, TikiGameState.startingHearts);
      expect(cubit.state.game.usedPlayerIds, isEmpty);
      expect(cubit.state.game.filledCellCount, 0);
      expect(cubit.state.elapsedMs, lessThan(500));
    });

    test('rapid cell taps only open one search dialog', () async {
      final cubit = _createCubit(handle);
      addTearDown(cubit.close);
      await cubit.loadBoard();

      final results = [
        cubit.onCellTapped(0, 0),
        cubit.onCellTapped(1, 1),
        cubit.onCellTapped(2, 2),
      ];

      expect(results.first, TikiCellTapResult.openedSearch);
      expect(
        results.skip(1),
        everyElement(TikiCellTapResult.rejectedDialogOpen),
      );
      expect(cubit.state.activeCell, const TikiActiveCell(row: 0, col: 0));
    });

    test('concurrent selectPlayer calls only apply one answer', () async {
      final cubit = _createCubit(handle);
      addTearDown(cubit.close);
      await cubit.loadBoard();

      final board = cubit.state.game.board!;
      final cell = await _findAnyValidCell(
        databaseHandle: handle,
        board: board,
      );
      expect(cell, isNotNull);

      cubit.onCellTapped(cell!.$1, cell.$2);

      final first = cubit.selectPlayer(cell.$3);
      final second = await cubit.selectPlayer(cell.$3);
      await first;

      expect(second, TikiSelectPlayerResult.rejectedLocked);
      expect(
        cubit.state.game.cellAt(cell.$1, cell.$2).player?.displayName,
        cell.$3.displayName,
      );
    });

    test('searchPlayers returns prefix matches', () async {
      final cubit = _createCubit(handle);
      addTearDown(cubit.close);
      await cubit.loadBoard();
      cubit.onCellTapped(0, 0);

      await cubit.searchPlayers('mohamed s');

      expect(cubit.state.searchResults, isNotEmpty);
      expect(
        cubit.state.searchResults.any(
          (player) => player.displayName == 'Mohamed Salah',
        ),
        isTrue,
      );
    });

    test('continueAfterFirstWin transitions to continuing', () async {
      final board = await BoardDao(handle.database).loadDefaultBoard();
      expect(board, isNotNull);

      final engine = TikiTakaGameEngine.instance;
      var game = engine.boardLoaded(engine.initial(), board!);
      final rowPlayers = <TikiPlayerSearchResult>[];
      for (var col = 0; col < 3; col++) {
        final player = await _findValidPlayer(
          databaseHandle: handle,
          board: board,
          row: 0,
          col: col,
          excludePlayerIds: rowPlayers.map((item) => item.id).toSet(),
        );
        expect(player, isNotNull);
        rowPlayers.add(player!);
      }

      var cells = game.cells.toList();
      for (var col = 0; col < 3; col++) {
        cells = cells
            .map(
              (cell) => cell.row == 0 && cell.col == col
                  ? cell.copyWith(player: rowPlayers[col])
                  : cell,
            )
            .toList(growable: false);
      }

      game = game.copyWith(
        cells: cells,
        status: TikiGameStatus.firstWin,
        usedPlayerIds: rowPlayers.map((player) => player.id).toSet(),
      );

      final cubit = TikiTakaCubit.forTest(
        dependencies: _dependencies(handle),
        initialState: TikiTakaState.initial(game),
      );
      addTearDown(cubit.close);

      expect(cubit.state.game.filledCellCount, 3);

      cubit.continueAfterFirstWin();

      expect(cubit.state.status, TikiGameStatus.continuing);
      expect(cubit.state.isPlayable, isTrue);
      expect(cubit.state.game.filledCellCount, 3);
    });

    test('completed and lost stop the timer', () async {
      final board = await BoardDao(handle.database).loadDefaultBoard();
      expect(board, isNotNull);

      final engine = TikiTakaGameEngine.instance;
      final completedCubit = TikiTakaCubit.forTest(
        dependencies: _dependencies(handle),
        initialState: TikiTakaState.initial(
          engine.boardLoaded(engine.initial(), board!).copyWith(
            status: TikiGameStatus.completed,
            elapsed: const Duration(seconds: 30),
          ),
        ),
      );
      addTearDown(completedCubit.close);

      completedCubit.refreshElapsedForTest();
      expect(completedCubit.state.elapsedMs, 30_000);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(completedCubit.state.elapsedMs, 30_000);

      final lostCubit = TikiTakaCubit.forTest(
        dependencies: _dependencies(handle),
        initialState: TikiTakaState.initial(
          engine.boardLoaded(engine.initial(), board).copyWith(
            status: TikiGameStatus.lost,
            hearts: 0,
            elapsed: const Duration(seconds: 45),
          ),
        ),
      );
      addTearDown(lostCubit.close);

      lostCubit.refreshElapsedForTest();
      expect(lostCubit.state.elapsedMs, 45_000);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(lostCubit.state.elapsedMs, 45_000);
    });
  });
}
