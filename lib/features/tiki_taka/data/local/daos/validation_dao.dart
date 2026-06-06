import 'package:sqflite/sqflite.dart';

import '../../models/tiki_player_search_result.dart';
import '../tiki_player_id.dart';

/// Validates a player against independent row/column attribute edges.
class ValidationDao {
  ValidationDao(this._database);

  final Database _database;

  static const _validationSql = '''
SELECT DISTINCT p.id, p.display_name, p.position, p.nation
FROM players p
INNER JOIN player_attributes a
  ON a.player_id = p.id AND a.attribute_id = ?
INNER JOIN player_attributes b
  ON b.player_id = p.id AND b.attribute_id = ?
WHERE p.id = ?
LIMIT 1
''';

  Future<bool> isValidPlayer({
    required String playerId,
    required String rowAttributeId,
    required String colAttributeId,
  }) async {
    final match = await validatePlayer(
      playerId: playerId,
      rowAttributeId: rowAttributeId,
      colAttributeId: colAttributeId,
    );
    return match != null;
  }

  Future<TikiPlayerSearchResult?> validatePlayer({
    required String playerId,
    required String rowAttributeId,
    required String colAttributeId,
  }) async {
    final rows = await _database.rawQuery(
      _validationSql,
      [rowAttributeId, colAttributeId, toTmPlayerId(playerId)],
    );

    if (rows.isEmpty) {
      return null;
    }

    return TikiPlayerSearchResult.fromMap(rows.first);
  }
}
