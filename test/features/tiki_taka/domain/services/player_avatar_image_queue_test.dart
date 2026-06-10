import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/tiki_taka/domain/services/player_avatar_image_queue.dart';

void main() {
  tearDown(PlayerAvatarImageQueue.instance.resetForTest);

  group('PlayerAvatarImageQueue', () {
    test('cacheKey is stable for url and size', () {
      expect(
        PlayerAvatarImageQueue.instance.cacheKey('https://example.com/a.jpg', 96),
        'https://example.com/a.jpg|96',
      );
    });

    test('allows up to five parallel downloads', () {
      expect(PlayerAvatarImageQueue.maxConcurrent, 5);
    });
  });
}
