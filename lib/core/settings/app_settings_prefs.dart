import 'package:shared_preferences/shared_preferences.dart';

import '../../features/game/domain/models/bot_difficulty.dart';
import '../../features/game/domain/models/game_mode.dart';
import 'app_settings_defaults.dart';

/// Persisted values for [AppSettingsController].
class AppSettingsSnapshot {
  const AppSettingsSnapshot({
    required this.soundEffectsEnabled,
    required this.musicEnabled,
    required this.vibrationEnabled,
    required this.bgmVolume,
    required this.sfxVolume,
    required this.aiGameMode,
    required this.aiDifficulty,
  });

  final bool soundEffectsEnabled;
  final bool musicEnabled;
  final bool vibrationEnabled;
  final double bgmVolume;
  final double sfxVolume;
  final GameMode aiGameMode;
  final BotDifficulty aiDifficulty;
}

/// Reads and writes user settings via [SharedPreferences].
class AppSettingsPrefs {
  AppSettingsPrefs({SharedPreferences? prefs}) : _prefs = prefs;

  static const String soundEffectsEnabledKey = 'soundEffectsEnabled';
  static const String musicEnabledKey = 'musicEnabled';
  static const String vibrationEnabledKey = 'vibrationEnabled';
  static const String bgmVolumeKey = 'bgmVolume';
  static const String sfxVolumeKey = 'sfxVolume';
  static const String aiGameModeKey = 'aiGameMode';
  static const String aiDifficultyKey = 'aiDifficulty';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<AppSettingsSnapshot> load() async {
    final prefs = await _instance;
    final modeName = prefs.getString(aiGameModeKey);
    final difficultyName = prefs.getString(aiDifficultyKey);
    return AppSettingsSnapshot(
      soundEffectsEnabled: prefs.getBool(soundEffectsEnabledKey) ?? true,
      musicEnabled: prefs.getBool(musicEnabledKey) ?? true,
      vibrationEnabled: prefs.getBool(vibrationEnabledKey) ?? true,
      bgmVolume: prefs.getDouble(bgmVolumeKey) ?? AppSettingsDefaults.bgmVolume,
      sfxVolume: prefs.getDouble(sfxVolumeKey) ?? AppSettingsDefaults.sfxVolume,
      aiGameMode: GameMode.values.firstWhere(
        (mode) => mode.name == modeName,
        orElse: () => GameMode.shift,
      ),
      aiDifficulty: BotDifficulty.values.firstWhere(
        (difficulty) => difficulty.name == difficultyName,
        orElse: () => BotDifficulty.easy,
      ),
    );
  }

  Future<void> setSoundEffectsEnabled(bool value) async {
    final prefs = await _instance;
    await prefs.setBool(soundEffectsEnabledKey, value);
  }

  Future<void> setMusicEnabled(bool value) async {
    final prefs = await _instance;
    await prefs.setBool(musicEnabledKey, value);
  }

  Future<void> setVibrationEnabled(bool value) async {
    final prefs = await _instance;
    await prefs.setBool(vibrationEnabledKey, value);
  }

  Future<void> setBgmVolume(double value) async {
    final prefs = await _instance;
    await prefs.setDouble(bgmVolumeKey, value);
  }

  Future<void> setSfxVolume(double value) async {
    final prefs = await _instance;
    await prefs.setDouble(sfxVolumeKey, value);
  }

  Future<void> setAiGameMode(GameMode value) async {
    final prefs = await _instance;
    await prefs.setString(aiGameModeKey, value.name);
  }

  Future<void> setAiDifficulty(BotDifficulty value) async {
    final prefs = await _instance;
    await prefs.setString(aiDifficultyKey, value.name);
  }
}
