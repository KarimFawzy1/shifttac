import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/tiki_taka/data/local/daos/player_search_dao.dart';
import '../../support/tiki_taka_dao_test_support.dart';

void main() {
  late TikiTakaTestDatabaseHandle handle;
  late PlayerSearchDao searchDao;

  setUpAll(ensureTikiTakaDaoTestInit);

  setUp(() async {
    handle = await openTikiTakaTestDatabase();
    searchDao = PlayerSearchDao(handle.database);
  });

  tearDown(() async {
    await handle.close();
  });

  group('PlayerSearchDao', () {
    test('prefix search finds Mohamed Salah by full name', () async {
      final results = await searchDao.search('mohamed salah');
      final ids = results.map((result) => result.id).toSet();

      expect(ids, contains('tm:148455'));
      expect(
        results.firstWhere((result) => result.id == 'tm:148455').displayName,
        'Mohamed Salah',
      );
    });

    test('D12 name prefix search includes Mohamed Salah', () async {
      final rows = await handle.database.rawQuery(
        '''
        SELECT p.id
        FROM players p
        WHERE p.search_text LIKE ?
        LIMIT 20
        ''',
        ['mohamed%'],
      );

      expect(
        rows.map((row) => row['id']).toList(),
        contains('tm:148455'),
      );
    });

    test('alias search finds Mohamed Salah by salah', () async {
      final results = await searchDao.search('salah');
      final ids = results.map((result) => result.id).toSet();

      expect(ids, contains('tm:148455'));
    });

    test('alias search finds Mohamed Salah by mo salah', () async {
      final results = await searchDao.search('mo salah');
      expect(results.any((result) => result.id == 'tm:148455'), isTrue);
    });

    test('search dedupes players by id across name and alias paths', () async {
      final results = await searchDao.search('mohamed salah');
      final salahMatches = results.where((result) => result.id == 'tm:148455');

      expect(salahMatches.length, 1);
    });

    test('accent-insensitive query matches normalized search_text', () async {
      final normalized = await searchDao.search('mohamed');
      final accented = await searchDao.search('Mohamed');

      expect(
        normalized.map((result) => result.id).toSet(),
        accented.map((result) => result.id).toSet(),
      );
    });
  });
}
