import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app_settings_prefs.dart';

/// App preferences backed by [SharedPreferences] when [AppSettingsPrefs] is provided.
///
/// Single instance is provided at the app root via [AppSettingsScope].
class AppSettingsController extends ChangeNotifier {
  AppSettingsController({
    bool soundEffectsEnabled = true,
    bool musicEnabled = true,
    bool vibrationEnabled = true,
    AppSettingsPrefs? prefs,
  })  : _prefs = prefs,
        _soundEffectsEnabled = soundEffectsEnabled,
        _musicEnabled = musicEnabled,
        _vibrationEnabled = vibrationEnabled;

  /// Loads persisted settings before the first frame.
  static Future<AppSettingsController> load() async {
    final prefs = AppSettingsPrefs();
    final snapshot = await prefs.load();
    return AppSettingsController(
      prefs: prefs,
      soundEffectsEnabled: snapshot.soundEffectsEnabled,
      musicEnabled: snapshot.musicEnabled,
      vibrationEnabled: snapshot.vibrationEnabled,
    );
  }

  final AppSettingsPrefs? _prefs;
  bool _soundEffectsEnabled;
  bool _musicEnabled;
  bool _vibrationEnabled;

  bool get soundEffectsEnabled => _soundEffectsEnabled;

  bool get musicEnabled => _musicEnabled;

  bool get vibrationEnabled => _vibrationEnabled;

  set soundEffectsEnabled(bool value) {
    if (_soundEffectsEnabled == value) {
      return;
    }
    _soundEffectsEnabled = value;
    notifyListeners();
    final store = _prefs;
    if (store != null) {
      unawaited(store.setSoundEffectsEnabled(value));
    }
  }

  set musicEnabled(bool value) {
    if (_musicEnabled == value) {
      return;
    }
    _musicEnabled = value;
    notifyListeners();
    final store = _prefs;
    if (store != null) {
      unawaited(store.setMusicEnabled(value));
    }
  }

  set vibrationEnabled(bool value) {
    if (_vibrationEnabled == value) {
      return;
    }
    _vibrationEnabled = value;
    notifyListeners();
    final store = _prefs;
    if (store != null) {
      unawaited(store.setVibrationEnabled(value));
    }
  }
}

/// Exposes the root [AppSettingsController] to the widget tree.
class AppSettingsScope extends InheritedNotifier<AppSettingsController> {
  const AppSettingsScope({
    super.key,
    required AppSettingsController settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettingsController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    assert(
      scope != null,
      'AppSettingsScope not found. Wrap MaterialApp with AppSettingsScope.',
    );
    return scope!.notifier!;
  }

  /// Reads settings without subscribing to updates.
  static AppSettingsController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppSettingsScope>();
    assert(
      scope != null,
      'AppSettingsScope not found. Wrap MaterialApp with AppSettingsScope.',
    );
    return scope!.notifier!;
  }
}
