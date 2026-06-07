import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/local/daos/attribute_pair_stats_dao.dart';
import '../../data/models/tiki_attribute.dart';
import '../../data/models/tiki_board.dart';

/// Builds playable 3×3 boards at runtime using [attribute_pair_stats].
///
/// Each axis gets 3 **distinct** attributes (no repeated club/nation/league/
/// position on the same side). Row and column headers may be all one type or a
/// mix of types. The same attribute cannot appear on both axes (rules §17).
/// At most **one** position header (GK/DEF/MID/FWD) may appear on the whole
/// board.
class TikiRandomBoardGenerator {
  TikiRandomBoardGenerator({
    required Database database,
    this.minIntersection = 3,
    this.maxAttempts = 500,
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

  final Database _database;
  final AttributePairStatsDao _pairStats;
  final Random _random;
  final int minIntersection;
  final int maxAttempts;

  Future<TikiBoard?> generate() async {
    final byType = await _loadAttributesByType();
    if (!_hasEnoughAttributesForBoard(byType)) {
      return null;
    }

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final rowAttributes = _pickAxisAttributes(byType: byType, excludeIds: const {});
      if (rowAttributes == null) {
        continue;
      }

      final rowIds = rowAttributes.map((attribute) => attribute.id).toSet();
      final rowHasPosition = rowAttributes.any((attribute) => attribute.isPosition);
      final columnAttributes = _pickAxisAttributes(
        byType: byType,
        excludeIds: rowIds,
        excludePositionType: rowHasPosition,
      );
      if (columnAttributes == null) {
        continue;
      }

      if (_sharesAttributeAcrossAxes(rowAttributes, columnAttributes)) {
        continue;
      }

      if (!hasValidPositionCountForBoardForTest(rowAttributes, columnAttributes)) {
        continue;
      }

      final validation = await _validateGrid(rowAttributes, columnAttributes);
      if (validation == null) {
        continue;
      }

      return TikiBoard(
        id: 'runtime-${DateTime.now().microsecondsSinceEpoch}',
        name: _boardName(rowAttributes, columnAttributes),
        minIntersection: validation,
        rowAttributes: rowAttributes,
        columnAttributes: columnAttributes,
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

  /// Picks three unique attributes for one axis (homogeneous or mixed type).
  List<TikiAttribute>? _pickAxisAttributes({
    required Map<String, List<TikiAttribute>> byType,
    required Set<String> excludeIds,
    bool excludePositionType = false,
  }) {
    final strategies = <List<TikiAttribute>? Function()>[
      () => _pickHomogeneousAxis(byType, excludeIds, excludePositionType),
      () => _pickMixedAxisFromPool(byType, excludeIds, excludePositionType),
      () => _pickOneAttributePerTypeAxis(byType, excludeIds, excludePositionType),
    ];

    final strategy = strategies[_random.nextInt(strategies.length)];
    final picked = strategy();
    if (picked == null || picked.length != _axisSize) {
      return null;
    }
    if (!hasUniqueAttributesWithinAxisForTest(picked)) {
      return null;
    }
    if (!hasValidPositionCountWithinAxisForTest(picked)) {
      return null;
    }
    return picked;
  }

  List<TikiAttribute>? _pickHomogeneousAxis(
    Map<String, List<TikiAttribute>> byType,
    Set<String> excludeIds,
    bool excludePositionType,
  ) {
    final eligibleTypes = _attributeTypes
        .where(
          (type) =>
              type != 'position' &&
              _availableAttributes(byType[type], excludeIds, excludePositionType)
                      .length >=
                  _axisSize,
        )
        .toList(growable: false);
    if (eligibleTypes.isEmpty) {
      return null;
    }

    final type = eligibleTypes[_random.nextInt(eligibleTypes.length)];
    final pool = _availableAttributes(byType[type], excludeIds, excludePositionType);
    return _sampleWithoutReplacement(pool, _axisSize);
  }

  List<TikiAttribute>? _pickMixedAxisFromPool(
    Map<String, List<TikiAttribute>> byType,
    Set<String> excludeIds,
    bool excludePositionType,
  ) {
    final pool = _attributeTypes
        .expand(
          (type) => _availableAttributes(byType[type], excludeIds, excludePositionType),
        )
        .toList(growable: false);
    return _sampleWithoutReplacement(pool, _axisSize);
  }

  List<TikiAttribute>? _pickOneAttributePerTypeAxis(
    Map<String, List<TikiAttribute>> byType,
    Set<String> excludeIds,
    bool excludePositionType,
  ) {
    final eligibleTypes = _attributeTypes
        .where(
          (type) =>
              (!excludePositionType || type != 'position') &&
              _availableAttributes(byType[type], excludeIds, excludePositionType)
                  .isNotEmpty,
        )
        .toList(growable: false);
    if (eligibleTypes.length < _axisSize) {
      return null;
    }

    eligibleTypes.shuffle(_random);
    final selectedTypes = eligibleTypes.take(_axisSize).toList(growable: false);
    final picked = <TikiAttribute>[];
    for (final type in selectedTypes) {
      final pool = _availableAttributes(byType[type], excludeIds, excludePositionType);
      final attribute = pool[_random.nextInt(pool.length)];
      picked.add(attribute);
      excludeIds = {...excludeIds, attribute.id};
      if (attribute.isPosition) {
        excludePositionType = true;
      }
    }
    return picked;
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

  List<TikiAttribute>? _sampleWithoutReplacement(
    List<TikiAttribute> pool,
    int count,
  ) {
    if (pool.length < count) {
      return null;
    }

    final copy = List<TikiAttribute>.from(pool)..shuffle(_random);
    return copy.take(count).toList(growable: false);
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
