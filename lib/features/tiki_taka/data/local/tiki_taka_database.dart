import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'tiki_taka_database_paths.dart';

/// Failure opening or preparing the Tiki-Taka SQLite database.
class TikiTakaDatabaseException implements Exception {
  const TikiTakaDatabaseException(this.code, [this.message]);

  final TikiTakaDatabaseErrorCode code;
  final String? message;

  @override
  String toString() => 'TikiTakaDatabaseException($code${message == null ? '' : ': $message'})';
}

enum TikiTakaDatabaseErrorCode {
  missingBundledAsset,
  invalidBundledDatabase,
  copyFailed,
  openFailed,
}

/// Read-only access to the bundled Tiki-Taka SQLite database.
///
/// Implements copy-on-first-use and fingerprint invalidation per
/// [docs/tiki-taka-database-contract.md].
abstract class TikiTakaDatabase {
  /// Shared lazy singleton for app runtime.
  static final TikiTakaDatabase instance = DefaultTikiTakaDatabase();

  /// Opens or reuses the app-local read-only database copy.
  Future<void> open();

  /// Closes the active connection if open.
  Future<void> close();

  /// Whether [database] is available.
  bool get isOpen;

  /// `meta.schema_version` from the opened database; null until [open] succeeds.
  String? get schemaVersion;

  /// Active read-only connection. Throws if not [isOpen].
  Database get database;
}

/// Default runtime implementation of [TikiTakaDatabase].
class DefaultTikiTakaDatabase implements TikiTakaDatabase {
  DefaultTikiTakaDatabase({
    AssetBundle? assetBundle,
    Future<SharedPreferences> Function()? sharedPreferences,
    Future<String> Function()? resolveLocalDatabasePath,
    DatabaseFactory? dbFactory,
  }) : _assetBundle = assetBundle ?? rootBundle,
       _sharedPreferences = sharedPreferences ?? SharedPreferences.getInstance,
       _resolveLocalDatabasePath =
           resolveLocalDatabasePath ?? TikiTakaDatabasePaths.resolveLocalDatabasePath,
       _databaseFactoryOverride = dbFactory;

  final AssetBundle _assetBundle;
  final Future<SharedPreferences> Function() _sharedPreferences;
  final Future<String> Function() _resolveLocalDatabasePath;
  final DatabaseFactory? _databaseFactoryOverride;

  DatabaseFactory get _databaseFactory =>
      _databaseFactoryOverride ?? databaseFactory;

  Database? _database;
  String? _schemaVersion;

  @override
  bool get isOpen => _database != null;

  @override
  String? get schemaVersion => _schemaVersion;

  @override
  Database get database {
    final db = _database;
    if (db == null) {
      throw StateError('TikiTakaDatabase is not open. Call open() first.');
    }
    return db;
  }

  @override
  Future<void> open() async {
    if (_database != null) {
      return;
    }

    final ByteData bundledData;
    try {
      bundledData = await _assetBundle.load(TikiTakaDatabasePaths.bundledAssetPath);
    } on FlutterError catch (error) {
      throw TikiTakaDatabaseException(
        TikiTakaDatabaseErrorCode.missingBundledAsset,
        error.message,
      );
    }

    final bundledBytes = bundledData.buffer.asUint8List(
      bundledData.offsetInBytes,
      bundledData.lengthInBytes,
    );

    final localPath = await _resolveLocalDatabasePath();
    final meta = await _readBundledMeta(
      bundledBytes,
      p.dirname(localPath),
    );

    final schemaVersion = meta[TikiTakaDatabasePaths.metaSchemaVersionKey];
    final sourceHash = meta[TikiTakaDatabasePaths.metaSourceCsvHashKey];
    if (schemaVersion == null || sourceHash == null) {
      throw TikiTakaDatabaseException(
        TikiTakaDatabaseErrorCode.invalidBundledDatabase,
        'meta.schema_version or meta.source_csv_hash is missing',
      );
    }

    final fingerprint = TikiTakaDatabasePaths.buildFingerprint(
      schemaVersion: schemaVersion,
      sourceCsvHash: sourceHash,
    );

    await _ensureLocalCopy(
      bundledBytes: bundledBytes,
      localPath: localPath,
      fingerprint: fingerprint,
    );

    try {
      _database = await _openReadOnly(localPath);
      _schemaVersion = schemaVersion;
    } on DatabaseException {
      await _deleteIfExists(localPath);
      await _ensureLocalCopy(
        bundledBytes: bundledBytes,
        localPath: localPath,
        fingerprint: fingerprint,
        forceCopy: true,
      );
      try {
        _database = await _openReadOnly(localPath);
        _schemaVersion = schemaVersion;
      } on DatabaseException catch (retryError) {
        throw TikiTakaDatabaseException(
          TikiTakaDatabaseErrorCode.openFailed,
          retryError.toString(),
        );
      }
    }
  }

  @override
  Future<void> close() async {
    final db = _database;
    _database = null;
    _schemaVersion = null;
    if (db != null) {
      await db.close();
    }
  }

  Future<Database> _openReadOnly(String localPath) {
    return _databaseFactory.openDatabase(
      localPath,
      options: OpenDatabaseOptions(readOnly: true),
    );
  }

  Future<void> _ensureLocalCopy({
    required Uint8List bundledBytes,
    required String localPath,
    required String fingerprint,
    bool forceCopy = false,
  }) async {
    final prefs = await _sharedPreferences();
    final storedFingerprint = prefs.getString(
      TikiTakaDatabasePaths.prefsFingerprintKey,
    );
    final localFile = File(localPath);

    final needsCopy = forceCopy ||
        !await localFile.exists() ||
        storedFingerprint != fingerprint;

    if (!needsCopy) {
      return;
    }

    try {
      if (await localFile.exists()) {
        await localFile.delete();
      }
      await localFile.parent.create(recursive: true);
      await localFile.writeAsBytes(bundledBytes, flush: true);
      await prefs.setString(
        TikiTakaDatabasePaths.prefsFingerprintKey,
        fingerprint,
      );
    } on IOException catch (error) {
      throw TikiTakaDatabaseException(
        TikiTakaDatabaseErrorCode.copyFailed,
        error.toString(),
      );
    }
  }

  Future<Map<String, String>> _readBundledMeta(
    Uint8List bundledBytes,
    String tempDirectory,
  ) async {
    final probePath = p.join(tempDirectory, 'tiki_taka_meta_probe.db');
    final probeFile = File(probePath);

    try {
      await probeFile.parent.create(recursive: true);
      await probeFile.writeAsBytes(bundledBytes, flush: true);

      final probeDb = await _databaseFactory.openDatabase(
        probePath,
        options: OpenDatabaseOptions(readOnly: true),
      );

      try {
        final rows = await probeDb.query(
          'meta',
          columns: ['key', 'value'],
          where: 'key IN (?, ?)',
          whereArgs: [
            TikiTakaDatabasePaths.metaSchemaVersionKey,
            TikiTakaDatabasePaths.metaSourceCsvHashKey,
          ],
        );

        return {
          for (final row in rows)
            row['key']! as String: row['value']! as String,
        };
      } finally {
        await probeDb.close();
      }
    } on DatabaseException catch (error) {
      throw TikiTakaDatabaseException(
        TikiTakaDatabaseErrorCode.invalidBundledDatabase,
        error.toString(),
      );
    } finally {
      if (await probeFile.exists()) {
        await probeFile.delete();
      }
    }
  }

  Future<void> _deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
