import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shifttac/features/tiki_taka/data/local/tiki_taka_database.dart';
import 'package:shifttac/features/tiki_taka/data/local/tiki_taka_database_paths.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _BundledDbAssetBundle extends AssetBundle {
  _BundledDbAssetBundle(this.bytes);

  final Uint8List bytes;

  @override
  Future<ByteData> load(String key) async {
    if (key == TikiTakaDatabasePaths.bundledAssetPath) {
      return ByteData.sublistView(bytes);
    }
    throw FlutterError('Asset not found: $key');
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    throw UnimplementedError();
  }

  @override
  void evict(String key) {}
}

class _MissingAssetBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) async {
    throw FlutterError('Unable to load asset: $key');
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    throw UnimplementedError();
  }

  @override
  void evict(String key) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late Uint8List bundledDbBytes;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('tiki_taka_db_test_');
    bundledDbBytes = await File('assets/db/tiki_taka.db').readAsBytes();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  DefaultTikiTakaDatabase createDatabase({
    AssetBundle? assetBundle,
    Future<String> Function()? resolveLocalDatabasePath,
  }) {
    return DefaultTikiTakaDatabase(
      assetBundle: assetBundle ?? _BundledDbAssetBundle(bundledDbBytes),
      resolveLocalDatabasePath:
          resolveLocalDatabasePath ??
          () async => p.join(tempDir.path, TikiTakaDatabasePaths.localFileName),
      dbFactory: databaseFactoryFfi,
    );
  }

  group('DefaultTikiTakaDatabase', () {
    test('open exposes schema_version and core tables', () async {
      final service = createDatabase();
      await service.open();

      expect(service.isOpen, isTrue);
      expect(service.schemaVersion, '1');

      final players = await service.database.rawQuery(
        'SELECT COUNT(*) AS c FROM players',
      );
      final boards = await service.database.rawQuery(
        'SELECT COUNT(*) AS c FROM boards',
      );
      final attributes = await service.database.rawQuery(
        'SELECT COUNT(*) AS c FROM attributes',
      );

      expect((players.first['c'] as int?) ?? 0, greaterThan(0));
      expect((boards.first['c'] as int?) ?? 0, greaterThanOrEqualTo(20));
      expect((attributes.first['c'] as int?) ?? 0, greaterThan(0));

      await service.close();
      expect(service.isOpen, isFalse);
    });

    test('open is idempotent', () async {
      final service = createDatabase();
      await service.open();
      final first = service.database;
      await service.open();
      expect(identical(first, service.database), isTrue);
      await service.close();
    });

    test('re-copies local DB when bundled fingerprint changes', () async {
      final service = createDatabase();
      await service.open();
      await service.close();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        TikiTakaDatabasePaths.prefsFingerprintKey,
        'stale:hash',
      );

      await service.open();
      await service.close();

      final storedFingerprint = prefs.getString(
        TikiTakaDatabasePaths.prefsFingerprintKey,
      );
      expect(storedFingerprint, isNot('stale:hash'));
      expect(storedFingerprint, contains(':'));
    });

    test('missing bundled asset returns controlled error', () async {
      final service = createDatabase(assetBundle: _MissingAssetBundle());

      await expectLater(
        service.open(),
        throwsA(
          isA<TikiTakaDatabaseException>().having(
            (error) => error.code,
            'code',
            TikiTakaDatabaseErrorCode.missingBundledAsset,
          ),
        ),
      );
      expect(service.isOpen, isFalse);
    });

    test('invalid bundled asset returns controlled error', () async {
      final service = createDatabase(
        assetBundle: _BundledDbAssetBundle(Uint8List.fromList([1, 2, 3, 4])),
      );

      await expectLater(
        service.open(),
        throwsA(
          isA<TikiTakaDatabaseException>().having(
            (error) => error.code,
            'code',
            TikiTakaDatabaseErrorCode.invalidBundledDatabase,
          ),
        ),
      );
      expect(service.isOpen, isFalse);
    });

    test('database getter throws when not open', () {
      final service = createDatabase();
      expect(
        () => service.database,
        throwsA(isA<StateError>()),
      );
    });

    test('recovers from corrupt local copy by re-copying bundled asset', () async {
      final service = createDatabase();
      await service.open();
      await service.close();

      final localPath = p.join(tempDir.path, TikiTakaDatabasePaths.localFileName);
      await File(localPath).writeAsBytes(const [0, 1, 2, 3, 4]);

      await service.open();
      expect(service.isOpen, isTrue);
      expect(service.schemaVersion, '1');

      final boards = await service.database.rawQuery(
        'SELECT COUNT(*) AS c FROM boards',
      );
      expect((boards.first['c'] as int?) ?? 0, greaterThanOrEqualTo(20));

      await service.close();
    });
  });
}
