import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/tiki_taka/data/local/search_query_normalizer.dart';

// Keep in sync with tool/etl/tests/test_search_transliteration.py
const _parityCases = <(String input, String expected)>[
  ('Virgil van Dijk', 'virgil van dijk'),
  ('Martin Ødegaard', 'martin odegaard'),
  ('Alexander Sørloth', 'alexander sorloth'),
  ('Simon Kjær', 'simon kjaer'),
  ('Stefan Kießling', 'stefan kiessling'),
  ('Kevin Großkreutz', 'kevin grosskreutz'),
  ('Luka Modrić', 'luka modric'),
  ('Hakan Çalhanoğlu', 'hakan calhanoglu'),
  ('Paweł Olkowski', 'pawel olkowski'),
  ('Yunus Mallı', 'yunus malli'),
  ('Milan Škriniar', 'milan skriniar'),
  ('Randal Kolo Muani', 'randal kolo muani'),
  ('Ionuț Radu', 'ionut radu'),
  ('Marcin Kamiński', 'marcin kaminski'),
  ('  Mohamed   Salah  ', 'mohamed salah'),
];

void main() {
  group('normalizeSearchQuery', () {
    for (final (input, expected) in _parityCases) {
      test('normalizes "$input"', () {
        expect(normalizeSearchQuery(input), expected);
      });
    }

    test('plain ASCII query is unchanged', () {
      expect(normalizeSearchQuery('odegaard'), 'odegaard');
      expect(normalizeSearchQuery('van dijk'), 'van dijk');
    });
  });
}
