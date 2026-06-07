import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/tiki_taka/data/local/daos/attribute_pair_stats_dao.dart';
import 'package:shifttac/features/tiki_taka/data/models/tiki_attribute.dart';
import 'package:shifttac/features/tiki_taka/domain/services/tiki_random_board_generator.dart';

import '../../data/local/tiki_taka_dao_test_support.dart';

void main() {
  late TikiTakaTestDatabaseHandle handle;
  late AttributePairStatsDao pairStats;

  setUp(() async {
    handle = await openTikiTakaTestDatabase();
    pairStats = AttributePairStatsDao(handle.database);
  });

  tearDown(() async {
    await handle.close();
  });

  group('TikiRandomBoardGenerator', () {
    test('generates a playable runtime board', () async {
      final generator = TikiRandomBoardGenerator(database: handle.database);
      final board = await generator.generate();

      expect(board, isNotNull);
      expect(board!.rowAttributes, hasLength(3));
      expect(board.columnAttributes, hasLength(3));
      expect(board.minIntersection, greaterThanOrEqualTo(3));

      expect(
        TikiRandomBoardGenerator.hasUniqueAttributesWithinAxisForTest(
          board.rowAttributes,
        ),
        isTrue,
      );
      expect(
        TikiRandomBoardGenerator.hasUniqueAttributesWithinAxisForTest(
          board.columnAttributes,
        ),
        isTrue,
      );

      expect(
        TikiRandomBoardGenerator.hasValidPositionCountForBoardForTest(
          board.rowAttributes,
          board.columnAttributes,
        ),
        isTrue,
      );

      final allHeaderIds = {
        ...board.rowAttributes.map((attribute) => attribute.id),
        ...board.columnAttributes.map((attribute) => attribute.id),
      };
      expect(allHeaderIds, hasLength(6));

      for (final row in board.rowAttributes) {
        for (final column in board.columnAttributes) {
          expect(row.id == column.id, isFalse);
          final count = await pairStats.playerCount(row.id, column.id);
          expect(count, greaterThanOrEqualTo(3));
        }
      }
    });

    test('can produce homogeneous and mixed-type axes over many seeds', () async {
      final seenHomogeneousRow = <String>{};
      var sawMixedRow = false;

      for (var seed = 0; seed < 80; seed++) {
        final generator = TikiRandomBoardGenerator(
          database: handle.database,
          random: Random(seed),
        );
        final board = await generator.generate();
        if (board == null) {
          continue;
        }

        final rowTypes = board.rowAttributes.map((attribute) => attribute.type).toSet();
        if (rowTypes.length == 1) {
          seenHomogeneousRow.add(rowTypes.first);
        } else {
          sawMixedRow = true;
        }
      }

      expect(seenHomogeneousRow, isNotEmpty);
      expect(sawMixedRow, isTrue);
    });

    test('rejects duplicate attributes within an axis', () {
      const liverpool = TikiAttribute(
        id: 'club:31',
        type: 'club',
        displayName: 'Liverpool',
        slug: 'liverpool',
        iconKey: 'club_31',
      );

      expect(
        TikiRandomBoardGenerator.hasUniqueAttributesWithinAxisForTest(
          const [liverpool, liverpool],
        ),
        isFalse,
      );
    });

    test('rejects more than one position on the same board', () {
      const goalkeeper = TikiAttribute(
        id: 'pos:GK',
        type: 'position',
        displayName: 'Goalkeeper',
        slug: 'gk',
        iconKey: 'pos_gk',
      );
      const defender = TikiAttribute(
        id: 'pos:DEF',
        type: 'position',
        displayName: 'Defender',
        slug: 'def',
        iconKey: 'pos_def',
      );
      const liverpool = TikiAttribute(
        id: 'club:31',
        type: 'club',
        displayName: 'Liverpool',
        slug: 'liverpool',
        iconKey: 'club_31',
      );

      const egypt = TikiAttribute(
        id: 'nation:egypt',
        type: 'nation',
        displayName: 'Egypt',
        slug: 'egypt',
        iconKey: 'nation_egypt',
      );

      expect(
        TikiRandomBoardGenerator.hasValidPositionCountForBoardForTest(
          const [goalkeeper, liverpool, egypt],
          const [defender, liverpool, egypt],
        ),
        isFalse,
      );
      expect(
        TikiRandomBoardGenerator.hasValidPositionCountWithinAxisForTest(
          const [goalkeeper, defender, liverpool],
        ),
        isFalse,
      );
    });

    test('rejects when the same attribute appears on row and column', () {
      const liverpool = TikiAttribute(
        id: 'club:31',
        type: 'club',
        displayName: 'Liverpool',
        slug: 'liverpool',
        iconKey: 'club_31',
      );

      expect(
        TikiRandomBoardGenerator.sharesAttributeAcrossAxesForTest(
          const [liverpool],
          const [liverpool],
        ),
        isTrue,
      );
    });
  });
}
