/// Normalizes user search input to match ETL `search_text` / alias fields.
String normalizeSearchQuery(String raw) {
  final lower = raw.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  return _stripDiacritics(lower);
}

String _stripDiacritics(String input) {
  const replacements = <String, String>{
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'æ': 'ae',
    'ç': 'c',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ñ': 'n',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ø': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'ÿ': 'y',
    'ß': 'ss',
    'œ': 'oe',
  };

  final buffer = StringBuffer();
  for (final char in input.split('')) {
    buffer.write(replacements[char] ?? char);
  }
  return buffer.toString();
}
