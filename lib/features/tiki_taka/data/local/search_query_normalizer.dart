import 'package:diacritic/diacritic.dart';

/// Normalizes user search input to match ETL `search_text` / alias fields.
///
/// Mirrors [make_search_text] in `tool/etl/search_transliteration.py`.
String normalizeSearchQuery(String raw) {
  final folded = transliterateForSearch(raw).toLowerCase();
  return folded.trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Step 1–3 of the Python transliteration pipeline (case preserved).
String transliterateForSearch(String value) {
  var text = value;
  for (final replacement in _specialReplacements) {
    text = text.replaceAll(replacement.source, replacement.target);
  }
  return removeDiacritics(text);
}

const _specialReplacements = <_Replacement>[
  _Replacement('œ', 'oe'),
  _Replacement('Œ', 'oe'),
  _Replacement('æ', 'ae'),
  _Replacement('Æ', 'ae'),
  _Replacement('ß', 'ss'),
  _Replacement('ø', 'o'),
  _Replacement('Ø', 'o'),
  _Replacement('ł', 'l'),
  _Replacement('Ł', 'l'),
  _Replacement('đ', 'd'),
  _Replacement('Đ', 'd'),
  _Replacement('ð', 'd'),
  _Replacement('Ð', 'd'),
  _Replacement('ı', 'i'),
];

class _Replacement {
  const _Replacement(this.source, this.target);

  final String source;
  final String target;
}
