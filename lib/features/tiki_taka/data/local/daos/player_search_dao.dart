import 'package:sqflite/sqflite.dart';

import '../../models/tiki_player_search_result.dart';
import '../search_query_normalizer.dart';

/// Prefix search over normalized player names and aliases.
class PlayerSearchDao {
  PlayerSearchDao(this._database, {this.limit = 20});

  final Database _database;
  final int limit;

  Future<List<TikiPlayerSearchResult>> search(String query) async {
    final normalized = normalizeSearchQuery(query);
    if (normalized.isEmpty) {
      return const [];
    }

    final prefixPattern = '$normalized%';

    final rows = await _database.rawQuery(
      '''
      SELECT DISTINCT p.id, p.display_name, p.position, p.nation
      FROM players p
      LEFT JOIN player_aliases pa ON pa.player_id = p.id
      WHERE p.search_text LIKE ? OR pa.alias LIKE ?
      ORDER BY p.display_name
      LIMIT ?
      ''',
      [prefixPattern, prefixPattern, limit],
    );

    return rows.map(TikiPlayerSearchResult.fromMap).toList(growable: false);
  }
}
