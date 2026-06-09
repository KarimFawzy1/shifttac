import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/tiki_taka/domain/services/tiki_attribute_svg_preprocessor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Villarreal st1 and st3 paths get blue fill inlined', () async {
    final raw = await rootBundle.loadString(
      'assets/tiki_taka/attrs/clubs/Villarreal.svg',
    );
    final result = TikiAttributeSvgPreprocessor.preprocess(raw);

    expect(result, isNot(contains('<style')));
    expect(
      RegExp(r'class="st1"[^>]*fill="#003764"').hasMatch(result),
      isTrue,
      reason: 'st1 should inline blue fill',
    );
    expect(
      RegExp(r'class="st3"[^>]*fill="#003764"').hasMatch(result),
      isTrue,
      reason: 'st3 should inline blue fill',
    );
    expect(
      RegExp(r'class="st7"[^>]*fill="#231F20"').hasMatch(result),
      isTrue,
      reason: 'st7 should inline black fill',
    );
  });

  test('Villarreal has no clip-only black ring overlay', () async {
    final raw = await rootBundle.loadString(
      'assets/tiki_taka/attrs/clubs/Villarreal.svg',
    );
    final result = TikiAttributeSvgPreprocessor.preprocess(raw);

    expect(result, isNot(contains('class="st6"')));
    expect(
      RegExp(r'class="st7"[^>]*d="M26\.2,63\.1').hasMatch(result),
      isFalse,
      reason: 'duplicate full-badge black ring should be removed',
    );
  });
}
