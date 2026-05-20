import 'package:shared_preferences/shared_preferences.dart';

/// Persisted values for [AppSettingsController].
class AppSettingsSnapshot {
  const AppSettingsSnapshot({
    required this.soundEffectsEnabled,
    required this.musicEnabled,
    required this.vibrationEnabled,
  });

  final bool soundEffectsEnabled;
  final bool musicEnabled;
  final bool vibrationEnabled;
}

/// Reads and writes user settings via [SharedPreferences].
class AppSettingsPrefs {
  AppSettingsPrefs({SharedPreferences? prefs}) : _prefs = prefs;

  static const String soundEffectsEnabledKey = 'soundEffectsEnabled';
  static const String musicEnabledKey = 'musicEnabled';
  static const String vibrationEnabledKey = 'vibrationEnabled';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<AppSettingsSnapshot> load() async {
    final prefs = await _instance;
    return AppSettingsSnapshot(
      soundEffectsEnabled: prefs.getBool(soundEffectsEnabledKey) ?? true,
      musicEnabled: prefs.getBool(musicEnabledKey) ?? true,
      vibrationEnabled: prefs.getBool(vibrationEnabledKey) ?? true,
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
}
