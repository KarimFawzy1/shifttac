import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Resolves DB `attributes.icon_key` values to bundled SVG asset paths via G2
/// manifest. Position keys are omitted from the manifest and render as text.
class TikiAttributeAssetManifest {
  TikiAttributeAssetManifest._(this._paths);

  static const String assetPath = 'assets/tiki_taka/attrs/manifest.json';

  final Map<String, String> _paths;

  /// Loads the shipped manifest from the asset bundle.
  static Future<TikiAttributeAssetManifest> load() async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final paths = decoded.map(
      (key, value) => MapEntry(key, value as String),
    );
    return TikiAttributeAssetManifest._(paths);
  }

  /// Test-only constructor with an explicit icon_key → asset path map.
  @visibleForTesting
  factory TikiAttributeAssetManifest.forTest(Map<String, String> paths) {
    return TikiAttributeAssetManifest._(Map.unmodifiable(paths));
  }

  /// Returns the SVG asset path for [iconKey], or `null` when unmapped.
  String? pathForIconKey(String iconKey) => _paths[iconKey];
}
