import 'package:sqflite/sqflite.dart';

import '../../models/tiki_player_search_result.dart';
import '../search_query_normalizer.dart';

/// Prefix search over normalized player names and aliases.
class PlayerSearchDao {
  PlayerSearchDao(this._database, {this.limit = 10});

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
      SELECT p.id, p.display_name, p.position, p.nation, p.image_url
      FROM players p
      LEFT JOIN player_aliases pa ON pa.player_id = p.id
      WHERE p.search_text LIKE ? OR pa.alias LIKE ?
      GROUP BY p.id
      ORDER BY
        p.search_rank DESC,
        MIN(CASE WHEN p.search_text LIKE ? THEN 0 ELSE 1 END),
        p.display_name COLLATE NOCASE ASC
      LIMIT ?
      ''',
      [prefixPattern, prefixPattern, prefixPattern, limit],
    );

    return rows.map(TikiPlayerSearchResult.fromMap).toList(growable: false);
  }
}
