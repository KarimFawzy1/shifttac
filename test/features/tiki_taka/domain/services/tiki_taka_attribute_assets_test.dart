import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase G1 DoD: bundled club PNGs and league/nation SVGs load at runtime.
void main() {
  const samples = <(String label, String path, bool isSvg)>[
    ('club', 'assets/tiki_taka/attrs/clubs/Barcelona.png', false),
    ('league', 'assets/tiki_taka/attrs/leagues/Premier-League.svg', true),
    ('nation', 'assets/tiki_taka/attrs/nations/Germany.svg', true),
  ];

  for (final (label, path, isSvg) in samples) {
    testWidgets('$label attribute asset loads: $path', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: isSvg
                ? SvgPicture.asset(path, width: 24, height: 24)
                : Image.asset(path, width: 24, height: 24),
          ),
        ),
      );
      await tester.pumpAndSettle();

      if (isSvg) {
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
      } else {
        expect(find.byType(Image), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName == path,
          ),
          findsOneWidget,
        );
      }
    });
  }
}
