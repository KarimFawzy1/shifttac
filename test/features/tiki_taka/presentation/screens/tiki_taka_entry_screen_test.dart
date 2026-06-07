import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shifttac/features/tiki_taka/data/local/tiki_taka_database.dart';
import 'package:shifttac/features/tiki_taka/data/local/tiki_taka_database_paths.dart';
import 'package:shifttac/features/tiki_taka/presentation/screens/tiki_taka_entry_screen.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/tiki_taka_database_error_view.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../tiki_taka_widget_test_support.dart';

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
    tempDir = await Directory.systemTemp.createTemp('tiki_entry_test_');
    bundledDbBytes = await File('assets/db/tiki_taka.db').readAsBytes();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  DefaultTikiTakaDatabase createDatabase({required AssetBundle assetBundle}) {
    return DefaultTikiTakaDatabase(
      assetBundle: assetBundle,
      resolveLocalDatabasePath:
          () async => p.join(tempDir.path, TikiTakaDatabasePaths.localFileName),
      dbFactory: databaseFactoryFfi,
    );
  }

  group('TikiTakaDatabaseErrorView', () {
    test('maps missing bundled asset to user copy', () {
      const error = TikiTakaDatabaseException(
        TikiTakaDatabaseErrorCode.missingBundledAsset,
      );
      expect(
        TikiTakaDatabaseErrorView.messageFor(error),
        contains('missing'),
      );
    });
  });

  group('TikiTakaEntryScreen', () {
    testWidgets('shows controlled error when bundled DB is missing', (
      tester,
    ) async {
      final database = createDatabase(assetBundle: _MissingAssetBundle());

      await tester.pumpWidget(
        wrapTikiGameplayScreen(TikiTakaEntryScreen(database: database)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Tiki-Taka unavailable'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('retry opens gameplay after bundled DB becomes available', (
      tester,
    ) async {
      var useMissingAsset = true;
      final database = DefaultTikiTakaDatabase(
        assetBundle: _SwitchingAssetBundle(
          missing: _MissingAssetBundle(),
          bundled: _BundledDbAssetBundle(bundledDbBytes),
          useMissing: () => useMissingAsset,
        ),
        resolveLocalDatabasePath:
            () async => p.join(tempDir.path, TikiTakaDatabasePaths.localFileName),
        dbFactory: databaseFactoryFfi,
      );

      await tester.pumpWidget(
        wrapTikiGameplayScreen(TikiTakaEntryScreen(database: database)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Tiki-Taka unavailable'), findsOneWidget);

      useMissingAsset = false;
      await database.close();
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Tiki-Taka unavailable'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });
  });
}

class _SwitchingAssetBundle extends AssetBundle {
  _SwitchingAssetBundle({
    required this.missing,
    required this.bundled,
    required this.useMissing,
  });

  final AssetBundle missing;
  final AssetBundle bundled;
  final bool Function() useMissing;

  @override
  Future<ByteData> load(String key) {
    return useMissing() ? missing.load(key) : bundled.load(key);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    return useMissing()
        ? missing.loadString(key, cache: cache)
        : bundled.loadString(key, cache: cache);
  }

  @override
  void evict(String key) {
    missing.evict(key);
    bundled.evict(key);
  }
}
