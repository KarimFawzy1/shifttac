import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/tiki_taka/data/local/daos/board_dao.dart';
import 'package:shifttac/features/tiki_taka/data/local/daos/player_search_dao.dart';
import 'package:shifttac/features/tiki_taka/domain/services/tiki_taka_release_budgets.dart';

import '../support/tiki_taka_dao_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TikiTakaTestDatabaseHandle handle;

  setUp(() async {
    handle = await openTikiTakaTestDatabase();
  });

  tearDown(() async {
    await handle.close();
  });

  group('TikiTaka release performance', () {
    test('default board load stays within budget', () async {
      final dao = BoardDao(handle.database);

      final stopwatch = Stopwatch()..start();
      final board = await dao.loadDefaultBoard();
      stopwatch.stop();

      expect(board, isNotNull);
      expect(
        stopwatch.elapsed,
        lessThanOrEqualTo(TikiTakaReleaseBudgets.maxBoardLoadDuration),
      );
    });

    test('player prefix search stays within budget', () async {
      final dao = PlayerSearchDao(handle.database);

      final stopwatch = Stopwatch()..start();
      final results = await dao.search('moh');
      stopwatch.stop();

      expect(results, isNotEmpty);
      expect(
        stopwatch.elapsed,
        lessThanOrEqualTo(TikiTakaReleaseBudgets.maxPlayerSearchDuration),
      );
    });
  });
}
