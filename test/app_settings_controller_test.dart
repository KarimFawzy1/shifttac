import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shifttac/core/settings/app_settings_controller.dart';
import 'package:shifttac/core/settings/app_settings_prefs.dart';

void main() {
  group('AppSettingsController volume', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('persists on release after live slider updates', () async {
      final prefs = AppSettingsPrefs();
      final controller = AppSettingsController(prefs: prefs);

      controller.setSfxVolume(0.5, persist: false);
      controller.setBgmVolume(0.25, persist: false);

      controller.setSfxVolume(0.5);
      controller.setBgmVolume(0.25);

      await Future<void>.delayed(Duration.zero);

      final snapshot = await prefs.load();
      expect(snapshot.sfxVolume, 0.5);
      expect(snapshot.bgmVolume, 0.25);
      expect(snapshot.soundEffectsEnabled, isTrue);
      expect(snapshot.musicEnabled, isTrue);
    });

    test('zero volume persists as disabled', () async {
      final prefs = AppSettingsPrefs();
      final controller = AppSettingsController(prefs: prefs);

      controller.setSfxVolume(0, persist: false);
      controller.setSfxVolume(0);

      await Future<void>.delayed(Duration.zero);

      final snapshot = await prefs.load();
      expect(snapshot.sfxVolume, 0);
      expect(snapshot.soundEffectsEnabled, isFalse);
    });
  });
}
