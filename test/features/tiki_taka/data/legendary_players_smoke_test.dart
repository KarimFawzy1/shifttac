import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/tiki_taka/data/local/daos/player_search_dao.dart';
import 'package:shifttac/features/tiki_taka/data/local/daos/validation_dao.dart';
import 'package:shifttac/features/tiki_taka/domain/services/tiki_taka_release_budgets.dart';

import '../support/tiki_taka_dao_test_support.dart';

void main() {
  late TikiTakaTestDatabaseHandle handle;
  late ValidationDao validationDao;
  late PlayerSearchDao searchDao;

  setUpAll(ensureTikiTakaDaoTestInit);

  setUp(() async {
    handle = await openTikiTakaTestDatabase();
    validationDao = ValidationDao(handle.database);
    searchDao = PlayerSearchDao(handle.database);
  });

  tearDown(() async {
    await handle.close();
  });

  group('Legendary players smoke', () {
    test('Maradona validates Argentina x Barcelona', () async {
      final match = await validationDao.validatePlayer(
        playerId: '8024',
        rowAttributeId: 'nation:argentina',
        colAttributeId: 'club:131',
      );

      expect(match, isNotNull);
      expect(match!.displayName, contains('Maradona'));
      expect(match.imageUrl, isNotNull);
      expect(match.imageUrl, startsWith('https://commons.wikimedia.org/'));
    });

    test('Di Stéfano validates Spain x Real Madrid', () async {
      final match = await validationDao.validatePlayer(
        playerId: '135778',
        rowAttributeId: 'nation:spain',
        colAttributeId: 'club:418',
      );

      expect(match, isNotNull);
      expect(match!.displayName, contains('Di St'));
    });

    test('Di Stéfano validates Argentina x Real Madrid', () async {
      final valid = await validationDao.isValidPlayer(
        playerId: '135778',
        rowAttributeId: 'nation:argentina',
        colAttributeId: 'club:418',
      );

      expect(valid, isTrue);
    });

    test('Di Stéfano rejects France x Real Madrid', () async {
      final valid = await validationDao.isValidPlayer(
        playerId: '135778',
        rowAttributeId: 'nation:france',
        colAttributeId: 'club:418',
      );

      expect(valid, isFalse);
    });

    test('Pelé validates Brazil x Santos', () async {
      final match = await validationDao.validatePlayer(
        playerId: '17121',
        rowAttributeId: 'nation:brazil',
        colAttributeId: 'club:221',
      );

      expect(match, isNotNull);
      expect(match!.displayName, contains('Pel'));
    });

    test('search mar returns Maradona in top 5', () async {
      final results = await searchDao.search('mar');
      final topFive = results.take(5).map((result) => result.id).toList();

      expect(topFive, contains('tm:8024'));
    });

    test('search maradona returns face image result', () async {
      final results = await searchDao.search('maradona');
      final maradona = results.firstWhere((result) => result.id == 'tm:8024');

      expect(maradona.displayName, contains('Maradona'));
      expect(maradona.imageUrl, isNotNull);
      expect(maradona.imageUrl, startsWith('https://commons.wikimedia.org/'));
    });

    test('Mohamed Salah regression still validates Egypt x Liverpool', () async {
      final valid = await validationDao.isValidPlayer(
        playerId: '148455',
        rowAttributeId: 'nation:egypt',
        colAttributeId: 'club:31',
      );

      expect(valid, isTrue);
    });

    test('legendary prefix search stays within budget', () async {
      final stopwatch = Stopwatch()..start();
      final results = await searchDao.search('mar');
      stopwatch.stop();

      expect(results, isNotEmpty);
      expect(
        stopwatch.elapsed,
        lessThanOrEqualTo(TikiTakaReleaseBudgets.maxPlayerSearchDuration),
      );
    });
  });
}
