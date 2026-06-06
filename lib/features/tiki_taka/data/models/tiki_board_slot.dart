import 'package:equatable/equatable.dart';

import 'tiki_attribute.dart';

/// One header cell on a board (`board_slots` joined to `attributes`).
class TikiBoardSlot extends Equatable {
  const TikiBoardSlot({
    required this.slotKind,
    required this.slotIndex,
    required this.attribute,
  });

  final String slotKind;
  final int slotIndex;
  final TikiAttribute attribute;

  bool get isRow => slotKind == 'row';
  bool get isColumn => slotKind == 'col';

  factory TikiBoardSlot.fromMap(Map<String, Object?> row) {
    return TikiBoardSlot(
      slotKind: row['slot_kind']! as String,
      slotIndex: row['slot_index']! as int,
      attribute: TikiAttribute(
        id: (row['attribute_id'] ?? row['id'])! as String,
        type: (row['attribute_type'] ?? row['type'])! as String,
        displayName: row['display_name']! as String,
        slug: row['slug']! as String,
        iconKey: row['icon_key']! as String,
      ),
    );
  }

  @override
  List<Object?> get props => [slotKind, slotIndex, attribute];
}
