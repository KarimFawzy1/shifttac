/// Normalizes football-logos.cc SVGs for [flutter_svg], which ignores CSS
/// class rules inside `<style>` blocks.
class TikiAttributeSvgPreprocessor {
  TikiAttributeSvgPreprocessor._();

  static final RegExp _styleBlock = RegExp(
    r'<style[^>]*>([\s\S]*?)</style>',
    caseSensitive: false,
  );
  static final RegExp _cssRule = RegExp(r'([^{]+)\{([^}]*)\}');
  static final RegExp _classSelector = RegExp(r'^\.([a-zA-Z0-9_-]+)$');
  static final RegExp _fillDecl = RegExp(
    r'fill\s*:\s*([^;}\s]+)',
    caseSensitive: false,
  );
  static final RegExp _tagWithClass = RegExp(
    r'<(path|circle|rect|ellipse|polygon|polyline|g)\b([^>]*?)\bclass="([^"]*)"([^>]*)>',
    caseSensitive: false,
  );
  static final RegExp _hasFillAttr = RegExp(r'\bfill\s*=', caseSensitive: false);
  static final RegExp _hasInlineFill = RegExp(
    r'style="[^"]*fill\s*:',
    caseSensitive: false,
  );

  /// Inlines CSS class fills and strips elements [flutter_svg] cannot render.
  static String preprocess(String raw) {
    final classFills = _parseClassFills(raw);

    var result = raw;
    result = result.replaceAll(
      RegExp(
        r'<metadata\b[^>]*(?:/>|>[\s\S]*?</metadata>)',
        caseSensitive: false,
      ),
      '',
    );
    result = result.replaceAll(_styleBlock, '');
    result = _inlineClassFills(result, classFills);
    result = _stripUnsupportedSvgFeatures(result);
    result = _stripUnsupportedStyleProperties(result);
    return result;
  }

  static Map<String, String> _parseClassFills(String raw) {
    final classFills = <String, String>{};

    for (final styleMatch in _styleBlock.allMatches(raw)) {
      final css = styleMatch.group(1)!;
      for (final rule in _cssRule.allMatches(css)) {
        final selectors = rule.group(1)!;
        final declarations = rule.group(2)!;
        final fillMatch = _fillDecl.firstMatch(declarations);
        if (fillMatch == null) {
          continue;
        }

        final fill = fillMatch.group(1)!;
        for (final selector in selectors.split(',')) {
          final classMatch = _classSelector.firstMatch(selector.trim());
          if (classMatch != null) {
            classFills[classMatch.group(1)!] = fill;
          }
        }
      }
    }

    return classFills;
  }

  static String _inlineClassFills(
    String svg,
    Map<String, String> classFills,
  ) {
    if (classFills.isEmpty) {
      return svg;
    }

    return svg.replaceAllMapped(_tagWithClass, (match) {
      final tagName = match.group(1)!;
      final beforeClass = match.group(2)!;
      final classValue = match.group(3)!;
      final afterClass = match.group(4)!;
      final attrs = '$beforeClass class="$classValue"$afterClass';

      if (_hasFillAttr.hasMatch(attrs) || _hasInlineFill.hasMatch(attrs)) {
        return match.group(0)!;
      }

      final classes = classValue.split(RegExp(r'\s+'));
      for (final className in classes) {
        final fill = classFills[className];
        if (fill != null) {
          return '<$tagName$beforeClass class="$classValue"$afterClass fill="$fill">';
        }
      }

      return match.group(0)!;
    });
  }

  static String _stripUnsupportedSvgFeatures(String svg) {
    var result = svg;
    result = result.replaceAll(
      RegExp(r'<filter[\s\S]*?</filter>', caseSensitive: false),
      '',
    );
    result = result.replaceAll(
      RegExp(r'\sfilter="[^"]*"', caseSensitive: false),
      '',
    );
    result = result.replaceAll(
      RegExp(r'\sclip-path="[^"]*"', caseSensitive: false),
      '',
    );
    return result;
  }

  static String _stripUnsupportedStyleProperties(String svg) {
    return svg.replaceAllMapped(
      RegExp(r'\sstyle="([^"]*)"', caseSensitive: false),
      (match) {
        var style = match.group(1)!;
        style = style.replaceAll(
          RegExp(r'clip-path\s*:\s*url\([^)]*\)\s*;?', caseSensitive: false),
          '',
        );
        style = style.replaceAll(
          RegExp(r'filter\s*:\s*url\([^)]*\)\s*;?', caseSensitive: false),
          '',
        );
        style = style.trim();
        if (style.endsWith(';')) {
          style = style.substring(0, style.length - 1).trim();
        }
        if (style.isEmpty) {
          return '';
        }
        return ' style="$style"';
      },
    );
  }
}
