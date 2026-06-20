import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/tiki_taka/presentation/debug/tiki_taka_debug_settings.dart';

void main() {
  tearDown(TikiTakaDebugSettings.instance.resetForTest);

  test('forceBoardAvatarLoading defaults to false', () {
    expect(TikiTakaDebugSettings.instance.forceBoardAvatarLoading, isFalse);
  });

  test('forceBoardAvatarLoading notifies listeners', () {
    var notifications = 0;
    TikiTakaDebugSettings.instance.addListener(() {
      notifications++;
    });

    TikiTakaDebugSettings.instance.forceBoardAvatarLoading = true;
    TikiTakaDebugSettings.instance.forceBoardAvatarLoading = true;

    expect(
      TikiTakaDebugSettings.instance.forceBoardAvatarLoading,
      isTrue,
    );
    expect(notifications, 1);
  });

  test('resetForTest clears forceBoardAvatarLoading', () {
    TikiTakaDebugSettings.instance.forceBoardAvatarLoading = true;
    TikiTakaDebugSettings.instance.resetForTest();
    expect(TikiTakaDebugSettings.instance.forceBoardAvatarLoading, isFalse);
  });
}
