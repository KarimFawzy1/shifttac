import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase G2 DoD: icon_key manifest maps shipped attributes to bundled SVGs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const manifestAsset = 'assets/tiki_taka/attrs/manifest.json';
  const positionKeys = {'pos_def', 'pos_fwd', 'pos_gk', 'pos_mid'};

  late Map<String, dynamic> manifest;

  setUpAll(() async {
    final raw = await rootBundle.loadString(manifestAsset);
    manifest = jsonDecode(raw) as Map<String, dynamic>;
  });

  test('manifest excludes position icon_keys', () {
    for (final key in positionKeys) {
      expect(manifest.containsKey(key), isFalse, reason: key);
    }
  });

  test('manifest covers 84 club, league, and nation icon_keys', () {
    expect(manifest.length, 84);
    expect(
      manifest.keys.where((key) => key.startsWith('club_')).length,
      54,
    );
    expect(
      manifest.keys.where((key) => key.startsWith('league_')).length,
      5,
    );
    expect(
      manifest.keys.where((key) => key.startsWith('nation_')).length,
      25,
    );
  });

  test('known icon_keys map to expected asset paths', () {
    expect(
      manifest['club_31'],
      'assets/tiki_taka/attrs/clubs/Liverpool.svg',
    );
    expect(
      manifest['league_gb1'],
      'assets/tiki_taka/attrs/leagues/Premier-League.svg',
    );
    expect(
      manifest['nation_egypt'],
      'assets/tiki_taka/attrs/nations/Egypt.svg',
    );
  });

  testWidgets('manifest paths load via SvgPicture.asset', (tester) async {
    final samples = [
      manifest['club_31']! as String,
      manifest['league_gb1']! as String,
      manifest['nation_egypt']! as String,
    ];

    for (final path in samples) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SvgPicture.asset(path, width: 24, height: 24),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SvgPicture &&
              widget.bytesLoader is SvgAssetLoader &&
              (widget.bytesLoader as SvgAssetLoader).assetName == path,
        ),
        findsOneWidget,
      );
    }
  });
}
