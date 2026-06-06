import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/tiki_taka/data/local/daos/board_dao.dart';
import 'tiki_taka_dao_test_support.dart';

void main() {
  late TikiTakaTestDatabaseHandle handle;
  late BoardDao boardDao;

  setUpAll(ensureTikiTakaDaoTestInit);

  setUp(() async {
    handle = await openTikiTakaTestDatabase();
    boardDao = BoardDao(handle.database);
  });

  tearDown(() async {
    await handle.close();
  });

  group('BoardDao', () {
    test('loadDefaultBoard returns Clubs x Nations with 3 rows and 3 columns', () async {
      final board = await boardDao.loadDefaultBoard();
      expect(board, isNotNull);
      expect(board!.rowAttributes, hasLength(3));
      expect(board.columnAttributes, hasLength(3));
      expect(board.rowAttributes.every((attr) => attr.type == 'club'), isTrue);
      expect(board.columnAttributes.every((attr) => attr.type == 'nation'), isTrue);
    });

    test('slot order matches slot_index within each kind', () async {
      final board = await boardDao.loadDefaultBoard();
      expect(board, isNotNull);

      final loaded = await boardDao.loadBoardById(board!.id);
      expect(loaded, isNotNull);

      final rowSlots = await handle.database.rawQuery(
        '''
        SELECT slot_index, attribute_id
        FROM board_slots
        WHERE board_id = ? AND slot_kind = 'row'
        ORDER BY slot_index
        ''',
        [board.id],
      );
      final colSlots = await handle.database.rawQuery(
        '''
        SELECT slot_index, attribute_id
        FROM board_slots
        WHERE board_id = ? AND slot_kind = 'col'
        ORDER BY slot_index
        ''',
        [board.id],
      );

      for (var index = 0; index < 3; index++) {
        expect(loaded!.rowAttributes[index].id, rowSlots[index]['attribute_id']);
        expect(loaded.columnAttributes[index].id, colSlots[index]['attribute_id']);
      }
    });

    test('loadBoardById returns null for unknown board', () async {
      expect(await boardDao.loadBoardById('missing-board'), isNull);
    });
  });
}
