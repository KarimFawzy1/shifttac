import 'package:equatable/equatable.dart';

/// Row from the `attributes` table.
class TikiAttribute extends Equatable {
  const TikiAttribute({
    required this.id,
    required this.type,
    required this.displayName,
    required this.slug,
    required this.iconKey,
  });

  final String id;
  final String type;
  final String displayName;
  final String slug;
  final String iconKey;

  factory TikiAttribute.fromMap(Map<String, Object?> row) {
    return TikiAttribute(
      id: row['id']! as String,
      type: row['type']! as String,
      displayName: row['display_name']! as String,
      slug: row['slug']! as String,
      iconKey: row['icon_key']! as String,
    );
  }

  bool get isPosition => type == 'position';

  @override
  List<Object?> get props => [id, type, displayName, slug, iconKey];
}
