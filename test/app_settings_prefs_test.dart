import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shifttac/core/settings/app_settings_prefs.dart';

void main() {
  group('AppSettingsPrefs', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('load returns defaults when nothing stored', () async {
      final prefs = AppSettingsPrefs();
      final snapshot = await prefs.load();

      expect(snapshot.soundEffectsEnabled, isTrue);
      expect(snapshot.musicEnabled, isTrue);
      expect(snapshot.vibrationEnabled, isTrue);
    });

    test('persists and reloads user choices', () async {
      final prefs = AppSettingsPrefs();

      await prefs.setSoundEffectsEnabled(false);
      await prefs.setMusicEnabled(false);
      await prefs.setVibrationEnabled(false);

      final reloaded = await prefs.load();
      expect(reloaded.soundEffectsEnabled, isFalse);
      expect(reloaded.musicEnabled, isFalse);
      expect(reloaded.vibrationEnabled, isFalse);
    });
  });
}
