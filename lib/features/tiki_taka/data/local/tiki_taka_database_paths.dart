import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Paths and cache keys for [TikiTakaDatabase].
///
/// See [docs/tiki-taka-database-contract.md].
class TikiTakaDatabasePaths {
  const TikiTakaDatabasePaths._();

  /// Bundled Flutter asset copied to app-local storage before open.
  static const bundledAssetPath = 'assets/db/tiki_taka.db';

  /// Filename for the app-local working copy.
  static const localFileName = 'tiki_taka.db';

  /// `meta` keys used to detect when the bundled DB changed.
  static const metaSchemaVersionKey = 'schema_version';
  static const metaSourceCsvHashKey = 'source_csv_hash';

  /// `SharedPreferences` key for the last installed DB fingerprint.
  static const prefsFingerprintKey = 'tiki_taka_db_fingerprint';

  /// Returns the app-local SQLite path (application support directory).
  static Future<String> resolveLocalDatabasePath() async {
    final supportDir = await getApplicationSupportDirectory();
    return p.join(supportDir.path, localFileName);
  }

  /// Fingerprint compared against [prefsFingerprintKey] to decide re-copy.
  static String buildFingerprint({
    required String schemaVersion,
    required String sourceCsvHash,
  }) {
    return '$schemaVersion:$sourceCsvHash';
  }
}
