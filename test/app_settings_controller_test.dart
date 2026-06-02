import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shifttac/core/settings/app_settings_controller.dart';
import 'package:shifttac/core/settings/app_settings_defaults.dart';
import 'package:shifttac/core/settings/app_settings_prefs.dart';
import 'package:shifttac/features/game/domain/models/bot_difficulty.dart';
import 'package:shifttac/features/game/domain/models/game_mode.dart';

void main() {
  group('AppSettingsController volume', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('persists on release after live slider updates', () async {
      final prefs = AppSettingsPrefs();
      final controller = AppSettingsController(prefs: prefs);

      controller.setSfxVolume(0.5, persist: false);
      controller.setBgmVolume(0.3, persist: false);

      controller.setSfxVolume(0.5);
      controller.setBgmVolume(0.3);

      await Future<void>.delayed(Duration.zero);

      final snapshot = await prefs.load();
      expect(snapshot.sfxVolume, 0.5);
      expect(snapshot.bgmVolume, AppSettingsDefaults.snapVolume(0.3));
      expect(snapshot.soundEffectsEnabled, isTrue);
      expect(snapshot.musicEnabled, isTrue);
    });

    test('live slider updates do not notify until persist', () {
      var notifyCount = 0;
      final controller = AppSettingsController();
      controller.addListener(() => notifyCount++);

      controller.setSfxVolume(0.5, persist: false);
      expect(controller.sfxVolume, 0.5);
      expect(notifyCount, 0);

      controller.setSfxVolume(0.5);
      expect(notifyCount, 1);
    });

    test('zero volume persists as disabled and keeps last level', () async {
      final prefs = AppSettingsPrefs();
      final controller = AppSettingsController(prefs: prefs);

      controller.setSfxVolume(0.45, persist: false);
      controller.setSfxVolume(0);
      controller.setSfxVolume(0);

      await Future<void>.delayed(Duration.zero);

      final snapshot = await prefs.load();
      expect(snapshot.sfxVolume, 0.5);
      expect(snapshot.soundEffectsEnabled, isFalse);
    });

    test('toggleSfxMute restores previous level', () {
      final controller = AppSettingsController();

      controller.setSfxVolume(0.6, persist: false);
      controller.toggleSfxMute();
      expect(controller.sfxVolume, 0);
      expect(controller.soundEffectsEnabled, isFalse);

      controller.toggleSfxMute();
      expect(controller.sfxVolume, AppSettingsDefaults.snapVolume(0.6));
      expect(controller.soundEffectsEnabled, isTrue);
    });
  });

  group('AppSettingsController AI defaults', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('setAiGameMode and setAiDifficulty persist values', () async {
      final prefs = AppSettingsPrefs();
      final controller = AppSettingsController(prefs: prefs);

      controller.setAiGameMode(GameMode.classic);
      controller.setAiDifficulty(BotDifficulty.hard);

      await Future<void>.delayed(Duration.zero);
      final snapshot = await prefs.load();

      expect(snapshot.aiGameMode, GameMode.classic);
      expect(snapshot.aiDifficulty, BotDifficulty.hard);
    });
  });
}
