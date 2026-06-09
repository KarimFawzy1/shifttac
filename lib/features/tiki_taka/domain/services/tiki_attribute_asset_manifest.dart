import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Resolves DB `attributes.icon_key` values to bundled SVG asset paths via G2
/// manifest. Position keys are omitted from the manifest and render as text.
class TikiAttributeAssetManifest {
  TikiAttributeAssetManifest._(this._paths);

  static const String assetPath = 'assets/tiki_taka/attrs/manifest.json';

  static Future<TikiAttributeAssetManifest>? _loadFuture;
  static TikiAttributeAssetManifest? _loaded;

  final Map<String, String> _paths;

  /// Cached manifest after the first successful [load], if any.
  static TikiAttributeAssetManifest? get loaded => _loaded;

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
    _loaded = null;
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

  /// Returns the SVG asset path for [iconKey], or `null` when unmapped.
  String? pathForIconKey(String iconKey) => _paths[iconKey];

  /// All bundled attribute SVG paths, sorted by [displayNameForAssetPath].
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
    final withoutExtension = fileName.endsWith('.svg')
        ? fileName.substring(0, fileName.length - 4)
        : fileName;
    return withoutExtension.replaceAll('-', ' ');
  }
}
