import 'package:equatable/equatable.dart';

/// Player row returned by search or validation queries.
class TikiPlayerSearchResult extends Equatable {
  const TikiPlayerSearchResult({
    required this.id,
    required this.displayName,
    this.position,
    this.nation,
    this.imageUrl,
  });

  final String id;
  final String displayName;
  final String? position;
  final String? nation;
  final String? imageUrl;

  factory TikiPlayerSearchResult.fromMap(Map<String, Object?> row) {
    return TikiPlayerSearchResult(
      id: row['id']! as String,
      displayName: row['display_name']! as String,
      position: row['position'] as String?,
      nation: row['nation'] as String?,
      imageUrl: row['image_url'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, displayName, position, nation, imageUrl];
}
