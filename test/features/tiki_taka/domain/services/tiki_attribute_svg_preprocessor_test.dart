import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/tiki_taka/domain/services/tiki_attribute_svg_preprocessor.dart';

void main() {
  test('inlines CSS class fills from style blocks', () {
    const raw = '''
<svg>
<style>.shp0{fill:#dedee2}.shp1{fill:#1b2838}</style>
<path class="shp0" d="M0 0"/>
<path class="shp1" d="M1 1"/>
</svg>
''';

    final result = TikiAttributeSvgPreprocessor.preprocess(raw);

    expect(result, contains('fill="#dedee2"'));
    expect(result, contains('fill="#1b2838"'));
    expect(result, isNot(contains('<style')));
  });

  test('does not override existing fill attributes', () {
    const raw = '''
<svg>
<style>.st0{fill:#000}</style>
<path class="st0" fill="#fff" d="M0 0"/>
</svg>
''';

    final result = TikiAttributeSvgPreprocessor.preprocess(raw);

    expect(result, contains('fill="#fff"'));
    expect(result, isNot(contains('fill="#000"')));
  });

  test('inlines fills from comma-separated CSS class selectors', () {
    const raw = '''
<svg>
<style>.st2,.st3{fill:#f89c1c}.st3{fill-rule:evenodd}</style>
<path class="st2" d="M0 0"/>
<path class="st3" d="M1 1"/>
</svg>
''';

    final result = TikiAttributeSvgPreprocessor.preprocess(raw);

    expect(result, contains('class="st2"'));
    expect(result, contains('class="st3"'));
    expect(
      RegExp(r'class="st2"[^>]*fill="#f89c1c"').hasMatch(result),
      isTrue,
    );
    expect(
      RegExp(r'class="st3"[^>]*fill="#f89c1c"').hasMatch(result),
      isTrue,
    );
  });

  test('strips unsupported filter and clip-path markup', () {
    const raw = '''
<svg>
<defs>
<clipPath id="h"><path d="M0 0"/></clipPath>
<filter id="i"><feGaussianBlur stdDeviation="3"/></filter>
</defs>
<path clip-path="url(#h)" filter="url(#i)" style="filter:url(#i);clip-path:url(#h)" d="M0 0"/>
</svg>
''';

    final result = TikiAttributeSvgPreprocessor.preprocess(raw);

    expect(result, isNot(contains('<filter')));
    expect(result, isNot(contains('feGaussianBlur')));
    expect(result, isNot(contains('filter=')));
    expect(result, isNot(contains('clip-path=')));
    expect(result, isNot(contains('filter:url')));
    expect(result, isNot(contains('clip-path:url')));
  });

  test('strips metadata and clip-path styles', () {
    const raw = '''
<svg>
<metadata>hidden</metadata>
<path style="fill:#fff;clip-path:url(#clip)" d="M0 0"/>
</svg>
''';

    final result = TikiAttributeSvgPreprocessor.preprocess(raw);

    expect(result, isNot(contains('<metadata')));
    expect(result, isNot(contains('clip-path')));
    expect(result, contains('fill:#fff'));
  });

  test('strips self-closing metadata elements', () {
    const raw = '''
<svg>
<metadata id="CorelCorpID_0Corel-Layer"/>
<path class="fil0" d="M0 0"/>
</svg>
''';

    final result = TikiAttributeSvgPreprocessor.preprocess(raw);

    expect(result, isNot(contains('<metadata')));
    expect(result, contains('<path class="fil0"'));
  });
}
