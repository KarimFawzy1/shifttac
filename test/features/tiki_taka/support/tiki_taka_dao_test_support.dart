import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shifttac/features/tiki_taka/data/local/tiki_taka_database.dart';
import 'package:shifttac/features/tiki_taka/data/local/tiki_taka_database_paths.dart';
import 'package:shifttac/features/tiki_taka/presentation/state/tiki_taka_cubit.dart';
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

bool _initialized = false;
late Uint8List _bundledDbBytes;

Future<void> ensureTikiTakaDaoTestInit() async {
  if (_initialized) {
    return;
  }

  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  _bundledDbBytes = await File('assets/db/tiki_taka.db').readAsBytes();
  _initialized = true;
}

class TikiTakaTestDatabaseHandle {
  TikiTakaTestDatabaseHandle._(this.database, this._tempDir, this._service);

  final Database database;
  final Directory _tempDir;
  final DefaultTikiTakaDatabase _service;

  Future<void> close() async {
    await _service.close();
    if (await _tempDir.exists()) {
      await _tempDir.delete(recursive: true);
    }
  }
}

Future<TikiTakaTestDatabaseHandle> openTikiTakaTestDatabase() async {
  await ensureTikiTakaDaoTestInit();
  SharedPreferences.setMockInitialValues({});

  final tempDir = await Directory.systemTemp.createTemp('tiki_taka_dao_test_');
  final service = DefaultTikiTakaDatabase(
    assetBundle: _BundledDbAssetBundle(_bundledDbBytes),
    resolveLocalDatabasePath: () async => p.join(
      tempDir.path,
      TikiTakaDatabasePaths.localFileName,
    ),
    dbFactory: databaseFactoryFfi,
  );
  await service.open();

  return TikiTakaTestDatabaseHandle._(service.database, tempDir, service);
}

TikiTakaDependencies tikiTakaTestDependencies(TikiTakaTestDatabaseHandle handle) {
  return TikiTakaDependencies.fromDatabase(handle.database);
}
