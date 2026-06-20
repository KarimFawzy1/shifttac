import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Phase D11 DoD: shipped [assets/db/tiki_taka.db] opens read-only.
void main() {
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;

  test('tiki_taka.db opens read-only with expected tables', () async {
    final dbFile = File('assets/db/tiki_taka.db');
    expect(dbFile.existsSync(), isTrue, reason: 'Run tool/etl/build_database.py first');

    // sqflite_common_ffi prefixes relative paths with its cache dir; use absolute.
    final db = await databaseFactory.openDatabase(
      dbFile.absolute.path,
      options: OpenDatabaseOptions(readOnly: true),
    );

    try {
      final players = await db.rawQuery('SELECT COUNT(*) AS c FROM players');
      final boards = await db.rawQuery('SELECT COUNT(*) AS c FROM boards');
      final attributes = await db.rawQuery('SELECT COUNT(*) AS c FROM attributes');
      final schema = await db.query(
        'meta',
        where: 'key = ?',
        whereArgs: ['schema_version'],
      );

      expect((players.first['c'] as int?) ?? 0, greaterThan(0));
      expect((boards.first['c'] as int?) ?? 0, greaterThanOrEqualTo(20));
      expect((attributes.first['c'] as int?) ?? 0, greaterThan(0));
      expect(schema.first['value'], anyOf('1', '2', '3'));

      if (schema.first['value'] == '2' || schema.first['value'] == '3') {
        final columns = await db.rawQuery('PRAGMA table_info(players)');
        final names = columns.map((row) => row['name'] as String).toSet();
        expect(names, contains('image_url'));

        if (schema.first['value'] == '3') {
          expect(names, contains('search_rank'));
        }

        final withImages = await db.rawQuery(
          'SELECT COUNT(*) AS c FROM players WHERE image_url IS NOT NULL',
        );
        expect((withImages.first['c'] as int?) ?? 0, greaterThan(0));

        final imageSource = await db.query(
          'meta',
          where: 'key = ?',
          whereArgs: ['player_image_source'],
        );
        expect(imageSource.first['value'], 'wikidata_p2446_p18_and_qid_fast_path');

        final sample = await db.rawQuery(
          "SELECT image_url FROM players WHERE image_url IS NOT NULL LIMIT 1",
        );
        final url = sample.first['image_url'] as String;
        expect(url.startsWith('https://commons.wikimedia.org/'), isTrue);
        expect(url.contains('%2520'), isFalse);
      }

      await expectLater(
        db.insert('players', {
          'id': 'tm:smoke',
          'display_name': 'Should Fail',
          'search_text': 'should fail',
        }),
        throwsA(isA<DatabaseException>()),
      );
    } finally {
      await db.close();
    }
  });
}
