import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/tiki_taka/domain/services/player_avatar_image_provider.dart';
import 'package:shifttac/features/tiki_taka/domain/services/player_avatar_image_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(PlayerAvatarImageQueue.instance.resetForTest);

  group('PlayerAvatarImageQueue', () {
    test('cacheKey is stable for url', () {
      expect(
        PlayerAvatarImageQueue.instance.cacheKey('https://example.com/a.jpg'),
        'https://example.com/a.jpg|$kPlayerAvatarDecodeSize',
      );
    });

    test('allows up to five parallel downloads', () {
      expect(PlayerAvatarImageQueue.maxConcurrent, 5);
    });

    test('isResolved tracks successfully loaded urls', () {
      const url = 'https://commons.wikimedia.org/wiki/Special:FilePath/test.jpg';
      expect(PlayerAvatarImageQueue.instance.isResolved(url), isFalse);
      PlayerAvatarImageQueue.instance.markResolved(url);
      expect(PlayerAvatarImageQueue.instance.isResolved(url), isTrue);
    });
  });
}
