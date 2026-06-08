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

    test('shipped DB includes club×club pair stats', () async {
      final count = await pairStats.playerCount('club:31', 'club:631');
      expect(count, greaterThanOrEqualTo(1));
    });

    test('can produce club×club and league×league boards over many seeds', () async {
      var sawClubOnBothAxes = false;
      var sawLeagueOnBothAxes = false;
      var sawMixedColumn = false;
      var sawMixedRow = false;
      var boardCount = 0;

      for (var seed = 0; seed < 60; seed++) {
        final generator = TikiRandomBoardGenerator(
          database: handle.database,
          random: Random(seed),
        );
        final board = await generator.generate();
        if (board == null) {
          continue;
        }

        boardCount++;
        final rowTypes =
            board.rowAttributes.map((attribute) => attribute.type).toSet();
        final columnTypes =
            board.columnAttributes.map((attribute) => attribute.type).toSet();

        if (rowTypes.length == 1 &&
            rowTypes.first == 'club' &&
            columnTypes.length == 1 &&
            columnTypes.first == 'club') {
          sawClubOnBothAxes = true;
        }
        if (rowTypes.contains('league') && columnTypes.contains('league')) {
          sawLeagueOnBothAxes = true;
        }
        if (columnTypes.length > 1) {
          sawMixedColumn = true;
        }
        if (rowTypes.length > 1) {
          sawMixedRow = true;
        }

        expect(
          TikiRandomBoardGenerator.hasNationOnAtMostOneAxisForTest(
            board.rowAttributes,
            board.columnAttributes,
          ),
          isTrue,
        );
      }

      expect(boardCount, greaterThan(0));
      expect(sawClubOnBothAxes, isTrue);
      expect(sawLeagueOnBothAxes, isTrue);
      expect(sawMixedColumn || sawMixedRow, isTrue);
    });

    test('limits nations to one per axis', () async {
      for (var seed = 0; seed < 80; seed++) {
        final generator = TikiRandomBoardGenerator(
          database: handle.database,
          random: Random(seed),
        );
        final board = await generator.generate();
        if (board == null) {
          continue;
        }

        expect(
          TikiRandomBoardGenerator.hasValidNationCountForBoardForTest(
            board.rowAttributes,
            board.columnAttributes,
          ),
          isTrue,
        );
      }
    });

    test('limits leagues to one per axis', () async {
      for (var seed = 0; seed < 80; seed++) {
        final generator = TikiRandomBoardGenerator(
          database: handle.database,
          random: Random(seed),
        );
        final board = await generator.generate();
        if (board == null) {
          continue;
        }

        expect(
          TikiRandomBoardGenerator.hasValidLeagueCountForBoardForTest(
            board.rowAttributes,
            board.columnAttributes,
          ),
          isTrue,
        );
      }
    });

    test('prefers club headers over all-league columns', () async {
      var boardsWithClubHeader = 0;

      for (var seed = 0; seed < 60; seed++) {
        final generator = TikiRandomBoardGenerator(
          database: handle.database,
          random: Random(seed),
        );
        final board = await generator.generate();
        if (board == null) {
          continue;
        }

        final headers = [...board.rowAttributes, ...board.columnAttributes];
        if (headers.any((attribute) => attribute.type == 'club')) {
          boardsWithClubHeader++;
        }
      }

      expect(boardsWithClubHeader, greaterThan(40));
    });

    test('rejects more than one league on the same axis', () {
      const premierLeague = TikiAttribute(
        id: 'league:GB1',
        type: 'league',
        displayName: 'Premier League',
        slug: 'premier-league',
        iconKey: 'league_GB1',
      );
      const laLiga = TikiAttribute(
        id: 'league:ES1',
        type: 'league',
        displayName: 'La Liga',
        slug: 'la-liga',
        iconKey: 'league_ES1',
      );

      expect(
        TikiRandomBoardGenerator.hasValidLeagueCountWithinAxisForTest(
          const [premierLeague, laLiga],
        ),
        isFalse,
      );
    });

    test('rejects nation on both axes', () {
      const egypt = TikiAttribute(
        id: 'nation:egypt',
        type: 'nation',
        displayName: 'Egypt',
        slug: 'egypt',
        iconKey: 'nation_egypt',
      );
      const england = TikiAttribute(
        id: 'nation:england',
        type: 'nation',
        displayName: 'England',
        slug: 'england',
        iconKey: 'nation_england',
      );
      const liverpool = TikiAttribute(
        id: 'club:31',
        type: 'club',
        displayName: 'Liverpool',
        slug: 'liverpool',
        iconKey: 'club_31',
      );

      expect(
        TikiRandomBoardGenerator.hasNationOnAtMostOneAxisForTest(
          const [egypt, liverpool, liverpool],
          const [england, liverpool, liverpool],
        ),
        isFalse,
      );
    });

    test('rejects more than one nation on the same axis', () {
      const egypt = TikiAttribute(
        id: 'nation:egypt',
        type: 'nation',
        displayName: 'Egypt',
        slug: 'egypt',
        iconKey: 'nation_egypt',
      );
      const england = TikiAttribute(
        id: 'nation:england',
        type: 'nation',
        displayName: 'England',
        slug: 'england',
        iconKey: 'nation_england',
      );

      expect(
        TikiRandomBoardGenerator.hasValidNationCountWithinAxisForTest(
          const [egypt, england],
        ),
        isFalse,
      );
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
