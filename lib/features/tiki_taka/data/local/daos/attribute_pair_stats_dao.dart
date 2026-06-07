import 'package:sqflite/sqflite.dart';

/// Reads precomputed row×column intersection counts (`attribute_pair_stats`).
class AttributePairStatsDao {
  AttributePairStatsDao(this._database);

  final Database _database;

  static (String, String) canonicalPair(String attrA, String attrB) {
    return attrA.compareTo(attrB) <= 0 ? (attrA, attrB) : (attrB, attrA);
  }

  Future<int> playerCount(String attrA, String attrB) async {
    final (canonicalA, canonicalB) = canonicalPair(attrA, attrB);
    final rows = await _database.query(
      'attribute_pair_stats',
      columns: ['player_count'],
      where: 'attr_a = ? AND attr_b = ?',
      whereArgs: [canonicalA, canonicalB],
      limit: 1,
    );
    if (rows.isEmpty) {
      return 0;
    }
    return rows.first['player_count']! as int;
  }
}
