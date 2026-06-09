import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/tiki_taka/data/models/tiki_player_search_result.dart';

void main() {
  group('TikiPlayerSearchResult', () {
    test('fromMap parses nullable image_url', () {
      final withImage = TikiPlayerSearchResult.fromMap({
        'id': 'tm:148455',
        'display_name': 'Mohamed Salah',
        'position': 'FWD',
        'nation': 'egypt',
        'image_url':
            'https://commons.wikimedia.org/wiki/Special:FilePath/Mohamed%20Salah%202018.jpg?width=128',
      });

      expect(withImage.imageUrl, isNotNull);
      expect(withImage.imageUrl, contains('commons.wikimedia.org'));

      final withoutImage = TikiPlayerSearchResult.fromMap({
        'id': 'tm:999',
        'display_name': 'No Image Player',
        'position': null,
        'nation': null,
        'image_url': null,
      });

      expect(withoutImage.imageUrl, isNull);
    });

    test('Equatable includes imageUrl', () {
      const a = TikiPlayerSearchResult(
        id: 'tm:1',
        displayName: 'A',
        imageUrl: 'https://commons.wikimedia.org/x',
      );
      const b = TikiPlayerSearchResult(
        id: 'tm:1',
        displayName: 'A',
        imageUrl: 'https://commons.wikimedia.org/y',
      );

      expect(a, isNot(equals(b)));
    });
  });
}
