import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/tiki_taka/data/local/daos/validation_dao.dart';
import '../../support/tiki_taka_dao_test_support.dart';

void main() {
  late TikiTakaTestDatabaseHandle handle;
  late ValidationDao validationDao;

  setUpAll(ensureTikiTakaDaoTestInit);

  setUp(() async {
    handle = await openTikiTakaTestDatabase();
    validationDao = ValidationDao(handle.database);
  });

  tearDown(() async {
    await handle.close();
  });

  group('ValidationDao', () {
    test('validates Mohamed Salah for Egypt x Liverpool', () async {
      final valid = await validationDao.isValidPlayer(
        playerId: '148455',
        rowAttributeId: 'nation:egypt',
        colAttributeId: 'club:31',
      );

      expect(valid, isTrue);

      final match = await validationDao.validatePlayer(
        playerId: 'tm:148455',
        rowAttributeId: 'nation:egypt',
        colAttributeId: 'club:31',
      );

      expect(match, isNotNull);
      expect(match!.displayName, 'Mohamed Salah');
      expect(match.imageUrl, isNotNull);
      expect(match.imageUrl, startsWith('https://commons.wikimedia.org/'));
    });

    test('rejects Salah for Egypt x Dortmund', () async {
      final valid = await validationDao.isValidPlayer(
        playerId: '148455',
        rowAttributeId: 'nation:egypt',
        colAttributeId: 'club:16',
      );

      expect(valid, isFalse);
      expect(
        await validationDao.validatePlayer(
          playerId: '148455',
          rowAttributeId: 'nation:egypt',
          colAttributeId: 'club:16',
        ),
        isNull,
      );
    });
  });
}
