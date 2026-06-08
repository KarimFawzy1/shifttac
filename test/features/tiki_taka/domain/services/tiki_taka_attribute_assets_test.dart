import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase G1 DoD: bundled club, league, and nation attribute SVGs load at runtime.
void main() {
  const samples = <(String label, String path)>[
    ('club', 'assets/tiki_taka/attrs/clubs/Barcelona.svg'),
    ('league', 'assets/tiki_taka/attrs/leagues/Premier-League.svg'),
    ('nation', 'assets/tiki_taka/attrs/nations/Germany.svg'),
  ];

  for (final (label, path) in samples) {
    testWidgets('$label attribute SVG loads: $path', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SvgPicture.asset(path, width: 24, height: 24),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SvgPicture), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SvgPicture &&
              widget.bytesLoader is SvgAssetLoader &&
              (widget.bytesLoader as SvgAssetLoader).assetName == path,
        ),
        findsOneWidget,
      );
    });
  }
}
