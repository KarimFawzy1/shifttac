import 'package:equatable/equatable.dart';

import 'tiki_attribute.dart';
import 'tiki_board_slot.dart';

/// Playable board with ordered row and column headers.
class TikiBoard extends Equatable {
  const TikiBoard({
    required this.id,
    required this.name,
    required this.minIntersection,
    required this.rowAttributes,
    required this.columnAttributes,
  });

  final String id;
  final String name;
  final int minIntersection;
  final List<TikiAttribute> rowAttributes;
  final List<TikiAttribute> columnAttributes;

  factory TikiBoard.fromSlots({
    required String id,
    required String name,
    required int minIntersection,
    required List<TikiBoardSlot> slots,
  }) {
    final rows = slots.where((slot) => slot.isRow).toList()
      ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));
    final columns = slots.where((slot) => slot.isColumn).toList()
      ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));

    return TikiBoard(
      id: id,
      name: name,
      minIntersection: minIntersection,
      rowAttributes: rows.map((slot) => slot.attribute).toList(growable: false),
      columnAttributes: columns
          .map((slot) => slot.attribute)
          .toList(growable: false),
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    minIntersection,
    rowAttributes,
    columnAttributes,
  ];
}
