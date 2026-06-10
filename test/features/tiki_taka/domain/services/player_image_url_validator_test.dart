import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/constants/app_constants.dart';
import 'package:shifttac/features/tiki_taka/domain/services/player_image_url_validator.dart';

void main() {
  group('playerImageNetworkHeaders', () {
    test('includes descriptive User-Agent for Wikimedia', () {
      expect(
        playerImageNetworkHeaders['User-Agent'],
        '${AppConstants.appName}/${AppConstants.appVersionLabel} '
        '(player-images; +https://github.com/KarimFawzy1/shifttac)',
      );
    });
  });

  group('isLoadablePlayerImageUrl', () {
    test('accepts HTTPS Commons Special:FilePath URLs', () {
      expect(
        isLoadablePlayerImageUrl(
          'https://commons.wikimedia.org/wiki/Special:FilePath/Mohamed%20Salah%202018.jpg?width=128',
        ),
        isTrue,
      );
    });

    test('rejects null, empty, and whitespace', () {
      expect(isLoadablePlayerImageUrl(null), isFalse);
      expect(isLoadablePlayerImageUrl(''), isFalse);
      expect(isLoadablePlayerImageUrl('   '), isFalse);
    });

    test('rejects non-HTTPS and wrong host', () {
      expect(
        isLoadablePlayerImageUrl(
          'http://commons.wikimedia.org/wiki/Special:FilePath/test.jpg',
        ),
        isFalse,
      );
      expect(
        isLoadablePlayerImageUrl('https://www.transfermarkt.com/img/test.jpg'),
        isFalse,
      );
      expect(
        isLoadablePlayerImageUrl('https://example.com/Special:FilePath/x.jpg'),
        isFalse,
      );
    });

    test('rejects Commons URLs without Special:FilePath', () {
      expect(
        isLoadablePlayerImageUrl('https://commons.wikimedia.org/wiki/Main_Page'),
        isFalse,
      );
    });
  });
}
