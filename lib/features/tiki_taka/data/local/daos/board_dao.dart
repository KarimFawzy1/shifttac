import 'package:sqflite/sqflite.dart';

import '../../models/tiki_board.dart';
import '../../models/tiki_board_slot.dart';

/// Reads curated boards and ordered header attributes.
class BoardDao {
  BoardDao(this._database);

  final Database _database;

  static const _clubsXNationsHaving = '''
    HAVING
      SUM(CASE WHEN bs.slot_kind = 'row' AND a.type = 'club' THEN 1 ELSE 0 END) = 3
      AND SUM(CASE WHEN bs.slot_kind = 'col' AND a.type = 'nation' THEN 1 ELSE 0 END) = 3
  ''';

  Future<TikiBoard?> loadBoardById(String boardId) async {
    final boardRows = await _database.query(
      'boards',
      columns: ['id', 'name', 'min_intersection'],
      where: 'id = ?',
      whereArgs: [boardId],
      limit: 1,
    );
    if (boardRows.isEmpty) {
      return null;
    }

    final boardRow = boardRows.first;
    final slots = await _loadSlots(boardId);
    return TikiBoard.fromSlots(
      id: boardRow['id']! as String,
      name: boardRow['name']! as String,
      minIntersection: boardRow['min_intersection']! as int,
      slots: slots,
    );
  }

  Future<TikiBoard?> loadDefaultBoard() async {
    final rows = await _database.rawQuery('''
      SELECT b.id
      FROM boards b
      JOIN board_slots bs ON bs.board_id = b.id
      JOIN attributes a ON a.id = bs.attribute_id
      GROUP BY b.id
      $_clubsXNationsHaving
      ORDER BY b.id
      LIMIT 1
    ''');

    if (rows.isEmpty) {
      return null;
    }

    return loadBoardById(rows.first['id']! as String);
  }

  Future<TikiBoard?> loadRandomDefaultBoard() async {
    final rows = await _database.rawQuery('''
      SELECT b.id
      FROM boards b
      JOIN board_slots bs ON bs.board_id = b.id
      JOIN attributes a ON a.id = bs.attribute_id
      GROUP BY b.id
      $_clubsXNationsHaving
      ORDER BY RANDOM()
      LIMIT 1
    ''');

    if (rows.isEmpty) {
      return null;
    }

    return loadBoardById(rows.first['id']! as String);
  }

  Future<List<TikiBoardSlot>> _loadSlots(String boardId) async {
    final rows = await _database.rawQuery(
      '''
      SELECT
        bs.slot_kind,
        bs.slot_index,
        a.id AS attribute_id,
        a.type AS attribute_type,
        a.display_name,
        a.slug,
        a.icon_key
      FROM board_slots bs
      INNER JOIN attributes a ON a.id = bs.attribute_id
      WHERE bs.board_id = ?
      ORDER BY
        CASE bs.slot_kind WHEN 'row' THEN 0 ELSE 1 END,
        bs.slot_index
      ''',
      [boardId],
    );

    return rows.map(TikiBoardSlot.fromMap).toList(growable: false);
  }
}
