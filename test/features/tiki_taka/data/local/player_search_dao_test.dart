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
      final salah = results.firstWhere((result) => result.id == 'tm:148455');
      expect(salah.displayName, 'Mohamed Salah');
      expect(salah.imageUrl, isNotNull);
      expect(salah.imageUrl, startsWith('https://commons.wikimedia.org/'));
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

    test('search returns null imageUrl when player has no image', () async {
      final row = await handle.database.rawQuery(
        '''
        SELECT p.id, p.display_name, p.position, p.nation, p.image_url
        FROM players p
        WHERE p.image_url IS NULL
        LIMIT 1
        ''',
      );
      expect(row, isNotEmpty);

      final playerId = row.first['id'] as String;
      final displayName = row.first['display_name'] as String;
      final searchText = displayName.toLowerCase();

      final results = await searchDao.search(searchText);
      final match = results.where((result) => result.id == playerId);

      expect(match, isNotEmpty);
      expect(match.first.imageUrl, isNull);
    });

    test('accent-insensitive query matches normalized search_text', () async {
      final normalized = await searchDao.search('mohamed');
      final accented = await searchDao.search('Mohamed');

      expect(
        normalized.map((result) => result.id).toSet(),
        accented.map((result) => result.id).toSet(),
      );
    });

    test('plain o finds Martin Odegaard from Ø', () async {
      final results = await searchDao.search('odegaard');

      expect(
        results.map((result) => result.id),
        contains('tm:316264'),
      );
    });

    test('plain o finds Alexander Sorloth from Ø', () async {
      final results = await searchDao.search('sorloth');

      expect(
        results.map((result) => result.id),
        contains('tm:238407'),
      );
    });

    test('famous players rank first for short prefixes', () async {
      final vi = await searchDao.search('vi');
      final cri = await searchDao.search('cri');
      final mes = await searchDao.search('mes');
      final xav = await searchDao.search('xav');

      expect(vi.first.id, 'tm:371998'); // Vinicius Junior
      expect(cri.first.id, 'tm:8198'); // Cristiano Ronaldo
      expect(mes.first.id, 'tm:28003'); // Lionel Messi
      expect(xav.first.id, 'tm:7607'); // Xavi
    });

    test('yaml aliases find Messi, Ronaldo, and Agüero nicknames', () async {
      final leoMessi = await searchDao.search('leo messi');
      final cr7 = await searchDao.search('cr7');
      final kunAguero = await searchDao.search('kun aguero');

      expect(leoMessi.map((r) => r.id), contains('tm:28003'));
      expect(cr7.map((r) => r.id), contains('tm:8198'));
      expect(kunAguero.map((r) => r.id), contains('tm:26399'));
    });

    test('yaml alias finds Rodrygo by rodrigo', () async {
      final results = await searchDao.search('rodrigo');

      expect(
        results.map((result) => result.id),
        contains('tm:412363'),
      );
    });

    test('yaml alias finds Min-jae Kim by kim min-jae', () async {
      final results = await searchDao.search('kim min-jae');

      expect(
        results.map((result) => result.id),
        contains('tm:503482'),
      );
      final match = results.firstWhere((result) => result.id == 'tm:503482');
      expect(match.displayName, 'Min-jae Kim');
    });

    test('mid-name phrase prefix finds Virgil van Dijk', () async {
      final results = await searchDao.search('van dijk');

      expect(
        results.map((result) => result.id),
        contains('tm:139208'),
      );
    });

    test('mid-name phrase prefix finds Randal Kolo Muani', () async {
      final results = await searchDao.search('kolo muani');

      expect(
        results.map((result) => result.id),
        contains('tm:487969'),
      );
    });

    test('accented query finds Luka Modric', () async {
      final ascii = await searchDao.search('modric');
      final accented = await searchDao.search('modrić');

      expect(
        ascii.map((result) => result.id).toSet(),
        accented.map((result) => result.id).toSet(),
      );
      expect(ascii.map((result) => result.id), contains('tm:27992'));
    });
  });
}
