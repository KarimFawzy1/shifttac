import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Resolves DB `attributes.icon_key` values to bundled asset paths via G2
/// manifest. Clubs use PNG crests; nations and leagues use SVG. Position keys
/// are omitted from the manifest and render as text.
class TikiAttributeAssetManifest {
  TikiAttributeAssetManifest._(this._paths);

  static const String assetPath = 'assets/tiki_taka/attrs/manifest.json';
  static const String galleryIndexPath = 'assets/tiki_taka/attrs/gallery_index.json';

  static Future<TikiAttributeAssetManifest>? _loadFuture;
  static Future<List<TikiGalleryAsset>>? _galleryLoadFuture;
  static TikiAttributeAssetManifest? _loaded;
  static List<TikiGalleryAsset>? _loadedGallery;

  final Map<String, String> _paths;

  /// Cached manifest after the first successful [load], if any.
  static TikiAttributeAssetManifest? get loaded => _loaded;

  /// Cached gallery entries after the first successful [loadGalleryAssets], if any.
  static List<TikiGalleryAsset>? get loadedGallery => _loadedGallery;

  /// Loads the shipped manifest from the asset bundle (cached after first call).
  static Future<TikiAttributeAssetManifest> load() {
    return _loadFuture ??= _loadFromAssets().then((manifest) {
      _loaded = manifest;
      return manifest;
    });
  }

  /// Starts loading the manifest without awaiting it.
  static void preload() {
    load();
    loadGalleryAssets();
  }

  /// Loads every bundled club PNG and nation SVG for the attribute gallery.
  static Future<List<TikiGalleryAsset>> loadGalleryAssets() {
    return _galleryLoadFuture ??= _loadGalleryFromAssets().then((entries) {
      _loadedGallery = entries;
      return entries;
    });
  }

  static Future<List<TikiGalleryAsset>> _loadGalleryFromAssets() async {
    final raw = await rootBundle.loadString(galleryIndexPath);
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
          (entry) => TikiGalleryAsset.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
  }

  static Future<TikiAttributeAssetManifest> _loadFromAssets() async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final paths = decoded.map(
      (key, value) => MapEntry(key, value as String),
    );
    return TikiAttributeAssetManifest._(paths);
  }

  @visibleForTesting
  static void resetCacheForTest() {
    _loadFuture = null;
    _galleryLoadFuture = null;
    _loaded = null;
    _loadedGallery = null;
  }

  /// Empty manifest when asset loading fails; headers fall back to text.
  factory TikiAttributeAssetManifest.empty() {
    return TikiAttributeAssetManifest._(const {});
  }

  /// Test-only constructor with an explicit icon_key → asset path map.
  @visibleForTesting
  factory TikiAttributeAssetManifest.forTest(Map<String, String> paths) {
    return TikiAttributeAssetManifest._(Map.unmodifiable(paths));
  }

  /// Returns the asset path for [iconKey], or `null` when unmapped.
  String? pathForIconKey(String iconKey) => _paths[iconKey];

  /// All bundled attribute asset paths, sorted by [displayNameForAssetPath].
  List<String> get allAssetPaths {
    final paths = _paths.values.toList()
      ..sort(
        (a, b) => displayNameForAssetPath(a).compareTo(
          displayNameForAssetPath(b),
        ),
      );
    return paths;
  }

  /// Human-readable label from an asset path (e.g. `Egypt.svg` → `Egypt`).
  static String displayNameForAssetPath(String assetPath) {
    final fileName = assetPath.split('/').last;
    final withoutExtension = fileName.replaceFirst(
      RegExp(r'\.(svg|png)$'),
      '',
    );
    return withoutExtension.replaceAll('-', ' ');
  }

  /// Whether [assetPath] points at a bundled club crest PNG.
  static bool isClubAssetPath(String assetPath) {
    return assetPath.contains('/attrs/clubs/') && assetPath.endsWith('.png');
  }
}

/// Bundled club or nation asset shown in the attribute gallery.
class TikiGalleryAsset {
  const TikiGalleryAsset({
    required this.kind,
    required this.path,
    required this.label,
  });

  final String kind;
  final String path;
  final String label;

  bool get isClub => kind == 'club';

  factory TikiGalleryAsset.fromJson(Map<String, dynamic> json) {
    return TikiGalleryAsset(
      kind: json['kind'] as String,
      path: json['path'] as String,
      label: json['label'] as String,
    );
  }
}
