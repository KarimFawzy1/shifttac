import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/local/daos/attribute_pair_stats_dao.dart';
import '../../data/models/tiki_attribute.dart';
import '../../data/models/tiki_board.dart';

/// Builds playable 3×3 boards at runtime using [attribute_pair_stats].
///
/// Each axis gets 3 **distinct** attributes. At most **one nation** and **one
/// league** per axis; at most **one nation** on the whole board (nation×nation
/// cells are not in the shipped stats). At most **one** position header on the
/// whole board. The same attribute cannot appear on both axes (rules §17).
///
/// Supports club×club (e.g. Liverpool×Chelsea → Salah) and league×league
/// cells when precomputed pair stats exist. Club-heavy templates are weighted
/// more heavily than nation/league/position mixes.
class TikiRandomBoardGenerator {
  TikiRandomBoardGenerator({
    required Database database,
    this.minIntersection = 3,
    this.maxAttempts = 200,
    this.columnAttemptsPerRow = 12,
    Random? random,
    AttributePairStatsDao? pairStatsDao,
  }) : _database = database,
       _pairStats = pairStatsDao ?? AttributePairStatsDao(database),
       _random = random ?? Random();

  static const int _axisSize = 3;

  static const List<String> _attributeTypes = [
    'club',
    'nation',
    'league',
    'position',
  ];

  /// Paired row/column type counts: (row clubs, nations, leagues, positions,
  /// col clubs, nations, leagues, positions, weight).
  static const List<
      (
        int rowClubs,
        int rowNations,
        int rowLeagues,
        int rowPositions,
        int colClubs,
        int colNations,
        int colLeagues,
        int colPositions,
        int weight,
      )> _boardTemplates = [
    (3, 0, 0, 0, 3, 0, 0, 0, 30),
    (3, 0, 0, 0, 0, 1, 1, 1, 25),
    (0, 1, 1, 1, 3, 0, 0, 0, 25),
    (2, 0, 1, 0, 2, 0, 1, 0, 12),
    (2, 1, 0, 0, 3, 0, 0, 0, 8),
    (3, 0, 0, 0, 2, 1, 0, 0, 8),
    (3, 0, 0, 0, 2, 0, 1, 0, 6),
  ];

  final Database _database;
  final AttributePairStatsDao _pairStats;
  final Random _random;
  final int minIntersection;
  final int maxAttempts;
  final int columnAttemptsPerRow;

  Future<TikiBoard?> generate() async {
    final byType = await _loadAttributesByType();
    if (!_hasEnoughAttributesForBoard(byType)) {
      return null;
    }

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final template = _rollBoardTemplate();
      if (template == null) {
        continue;
      }

      final rowAttributes = _pickAxisFromComposition(
        byType: byType,
        excludeIds: const {},
        clubs: template.$1,
        nations: template.$2,
        leagues: template.$3,
        positions: template.$4,
      );
      if (rowAttributes == null) {
        continue;
      }

      final rowIds = rowAttributes.map((attribute) => attribute.id).toSet();
      final rowHasPosition = rowAttributes.any((attribute) => attribute.isPosition);

      final validColumns =
          <(List<TikiAttribute> attributes, int minIntersection)>[];

      for (var columnAttempt = 0;
          columnAttempt < columnAttemptsPerRow;
          columnAttempt++) {
        final columnAttributes = _pickAxisFromComposition(
          byType: byType,
          excludeIds: rowIds,
          clubs: template.$5,
          nations: template.$6,
          leagues: template.$7,
          positions: template.$8,
          excludePositionType: rowHasPosition,
        );
        if (columnAttributes == null) {
          continue;
        }

        if (_sharesAttributeAcrossAxes(rowAttributes, columnAttributes)) {
          continue;
        }

        if (!hasValidPositionCountForBoardForTest(
          rowAttributes,
          columnAttributes,
        )) {
          continue;
        }

        if (!hasValidNationCountForBoardForTest(
          rowAttributes,
          columnAttributes,
        )) {
          continue;
        }

        if (!hasValidLeagueCountForBoardForTest(
          rowAttributes,
          columnAttributes,
        )) {
          continue;
        }

        if (!hasNationOnAtMostOneAxisForTest(
          rowAttributes,
          columnAttributes,
        )) {
          continue;
        }

        final validation = await _validateGrid(rowAttributes, columnAttributes);
        if (validation == null) {
          continue;
        }

        validColumns.add((columnAttributes, validation));
      }

      if (validColumns.isEmpty) {
        continue;
      }

      final chosen = validColumns[_random.nextInt(validColumns.length)];
      return TikiBoard(
        id: 'runtime-${DateTime.now().microsecondsSinceEpoch}',
        name: _boardName(rowAttributes, chosen.$1),
        minIntersection: chosen.$2,
        rowAttributes: rowAttributes,
        columnAttributes: chosen.$1,
      );
    }

    return null;
  }

  bool _hasEnoughAttributesForBoard(
    Map<String, List<TikiAttribute>> byType,
  ) {
    final total = byType.values.fold<int>(
      0,
      (count, attributes) => count + attributes.length,
    );
    return total >= _axisSize * 2;
  }

  List<TikiAttribute>? _pickAxisFromComposition({
    required Map<String, List<TikiAttribute>> byType,
    required Set<String> excludeIds,
    required int clubs,
    required int nations,
    required int leagues,
    required int positions,
    bool excludePositionType = false,
  }) {
    if (clubs + nations + leagues + positions != _axisSize) {
      return null;
    }

    final typeSlots = _typeSlotsFromCounts(
      clubs: clubs,
      nations: nations,
      leagues: leagues,
      positions: positions,
    )..shuffle(_random);

    final picked = <TikiAttribute>[];
    var localExclude = Set<String>.from(excludeIds);
    var excludePosition = excludePositionType;

    for (final type in typeSlots) {
      final pool = _availableAttributes(
        byType[type],
        localExclude,
        excludePosition,
      );
      if (pool.isEmpty) {
        return null;
      }

      final attribute = pool[_random.nextInt(pool.length)];
      picked.add(attribute);
      localExclude = {...localExclude, attribute.id};
      if (attribute.isPosition) {
        excludePosition = true;
      }
    }

    if (!hasUniqueAttributesWithinAxisForTest(picked)) {
      return null;
    }
    if (!hasValidPositionCountWithinAxisForTest(picked)) {
      return null;
    }
    if (!hasValidNationCountWithinAxisForTest(picked)) {
      return null;
    }
    if (!hasValidLeagueCountWithinAxisForTest(picked)) {
      return null;
    }

    picked.shuffle(_random);
    return picked;
  }

  (
    int rowClubs,
    int rowNations,
    int rowLeagues,
    int rowPositions,
    int colClubs,
    int colNations,
    int colLeagues,
    int colPositions,
  )? _rollBoardTemplate() {
    final totalWeight = _boardTemplates.fold<int>(
      0,
      (sum, template) => sum + template.$9,
    );
    var roll = _random.nextInt(totalWeight);
    for (final template in _boardTemplates) {
      roll -= template.$9;
      if (roll < 0) {
        return (
          template.$1,
          template.$2,
          template.$3,
          template.$4,
          template.$5,
          template.$6,
          template.$7,
          template.$8,
        );
      }
    }

    final fallback = _boardTemplates.last;
    return (
      fallback.$1,
      fallback.$2,
      fallback.$3,
      fallback.$4,
      fallback.$5,
      fallback.$6,
      fallback.$7,
      fallback.$8,
    );
  }

  List<String> _typeSlotsFromCounts({
    required int clubs,
    required int nations,
    required int leagues,
    required int positions,
  }) {
    final slots = <String>[];
    for (var index = 0; index < clubs; index++) {
      slots.add('club');
    }
    for (var index = 0; index < nations; index++) {
      slots.add('nation');
    }
    for (var index = 0; index < leagues; index++) {
      slots.add('league');
    }
    for (var index = 0; index < positions; index++) {
      slots.add('position');
    }
    return slots;
  }

  List<TikiAttribute> _availableAttributes(
    List<TikiAttribute>? attributes,
    Set<String> excludeIds, [
    bool excludePositionType = false,
  ]) {
    if (attributes == null) {
      return const [];
    }
    return attributes
        .where(
          (attribute) =>
              !excludeIds.contains(attribute.id) &&
              !(excludePositionType && attribute.isPosition),
        )
        .toList(growable: false);
  }

  bool _sharesAttributeAcrossAxes(
    List<TikiAttribute> rows,
    List<TikiAttribute> columns,
  ) {
    return sharesAttributeAcrossAxesForTest(rows, columns);
  }

  Future<int?> _validateGrid(
    List<TikiAttribute> rows,
    List<TikiAttribute> columns,
  ) async {
    var weakest = 1 << 30;

    for (final row in rows) {
      for (final column in columns) {
        final count = await _pairStats.playerCount(row.id, column.id);
        if (count < minIntersection) {
          return null;
        }
        if (count < weakest) {
          weakest = count;
        }
      }
    }

    return weakest;
  }

  Future<Map<String, List<TikiAttribute>>> _loadAttributesByType() async {
    final byType = <String, List<TikiAttribute>>{};
    for (final type in _attributeTypes) {
      final rows = await _database.query(
        'attributes',
        where: 'type = ?',
        whereArgs: [type],
        orderBy: 'id',
      );
      byType[type] = rows.map(TikiAttribute.fromMap).toList(growable: false);
    }
    return byType;
  }

  String _boardName(
    List<TikiAttribute> rows,
    List<TikiAttribute> columns,
  ) {
    final rowLabel = rows.map((attribute) => attribute.displayName).join(' · ');
    final colLabel = columns.map((attribute) => attribute.displayName).join(' · ');
    return '$rowLabel × $colLabel';
  }

  @visibleForTesting
  static bool hasNationOnAtMostOneAxisForTest(
    List<TikiAttribute> rows,
    List<TikiAttribute> columns,
  ) {
    final rowHasNation = rows.any((attribute) => attribute.type == 'nation');
    final colHasNation = columns.any((attribute) => attribute.type == 'nation');
    return !(rowHasNation && colHasNation);
  }

  @visibleForTesting
  static bool hasValidLeagueCountWithinAxisForTest(
    List<TikiAttribute> attributes,
  ) {
    return attributes.where((attribute) => attribute.type == 'league').length <= 1;
  }

  @visibleForTesting
  static bool hasValidLeagueCountForBoardForTest(
    List<TikiAttribute> rows,
    List<TikiAttribute> columns,
  ) {
    return hasValidLeagueCountWithinAxisForTest(rows) &&
        hasValidLeagueCountWithinAxisForTest(columns);
  }

  @visibleForTesting
  static bool hasValidNationCountWithinAxisForTest(
    List<TikiAttribute> attributes,
  ) {
    return attributes.where((attribute) => attribute.type == 'nation').length <= 1;
  }

  @visibleForTesting
  static bool hasValidNationCountForBoardForTest(
    List<TikiAttribute> rows,
    List<TikiAttribute> columns,
  ) {
    return hasValidNationCountWithinAxisForTest(rows) &&
        hasValidNationCountWithinAxisForTest(columns);
  }

  @visibleForTesting
  static bool hasValidPositionCountWithinAxisForTest(
    List<TikiAttribute> attributes,
  ) {
    return attributes.where((attribute) => attribute.isPosition).length <= 1;
  }

  @visibleForTesting
  static bool hasValidPositionCountForBoardForTest(
    List<TikiAttribute> rows,
    List<TikiAttribute> columns,
  ) {
    final positionCount = [
      ...rows,
      ...columns,
    ].where((attribute) => attribute.isPosition).length;
    return positionCount <= 1;
  }

  @visibleForTesting
  static bool hasUniqueAttributesWithinAxisForTest(
    List<TikiAttribute> attributes,
  ) {
    return attributes.map((attribute) => attribute.id).toSet().length ==
        attributes.length;
  }

  @visibleForTesting
  static bool sharesAttributeAcrossAxesForTest(
    List<TikiAttribute> rows,
    List<TikiAttribute> columns,
  ) {
    final columnIds = columns.map((attribute) => attribute.id).toSet();
    return rows.any((attribute) => columnIds.contains(attribute.id));
  }
}
