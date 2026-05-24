import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app_settings_defaults.dart';
import 'app_settings_prefs.dart';

/// App preferences backed by [SharedPreferences] when [AppSettingsPrefs] is provided.
///
/// Single instance is provided at the app root via [AppSettingsScope].
class AppSettingsController extends ChangeNotifier {
  AppSettingsController({
    bool soundEffectsEnabled = true,
    bool musicEnabled = true,
    bool vibrationEnabled = true,
    double bgmVolume = AppSettingsDefaults.bgmVolume,
    double sfxVolume = AppSettingsDefaults.sfxVolume,
    AppSettingsPrefs? prefs,
  })  : _prefs = prefs,
        _soundEffectsEnabled = soundEffectsEnabled,
        _musicEnabled = musicEnabled,
        _vibrationEnabled = vibrationEnabled,
        _bgmVolume = _clampVolume(bgmVolume),
        _sfxVolume = _clampVolume(sfxVolume);

  /// Loads persisted settings before the first frame.
  static Future<AppSettingsController> load() async {
    final prefs = AppSettingsPrefs();
    final snapshot = await prefs.load();
    return AppSettingsController(
      prefs: prefs,
      soundEffectsEnabled: snapshot.soundEffectsEnabled,
      musicEnabled: snapshot.musicEnabled,
      vibrationEnabled: snapshot.vibrationEnabled,
      bgmVolume: _volumeForEnabled(
        enabled: snapshot.musicEnabled,
        stored: snapshot.bgmVolume,
        defaultVolume: AppSettingsDefaults.bgmVolume,
      ),
      sfxVolume: _volumeForEnabled(
        enabled: snapshot.soundEffectsEnabled,
        stored: snapshot.sfxVolume,
        defaultVolume: AppSettingsDefaults.sfxVolume,
      ),
    );
  }

  static double _volumeForEnabled({
    required bool enabled,
    required double stored,
    required double defaultVolume,
  }) {
    if (!enabled) {
      return 0;
    }
    final snapped = _clampVolume(stored);
    return snapped > 0 ? snapped : defaultVolume;
  }

  static double _clampVolume(double value) =>
      AppSettingsDefaults.snapVolume(value.clamp(0.0, 1.0));

  final AppSettingsPrefs? _prefs;
  bool _soundEffectsEnabled;
  bool _musicEnabled;
  bool _vibrationEnabled;
  double _bgmVolume;
  double _sfxVolume;

  bool get soundEffectsEnabled => _soundEffectsEnabled;

  bool get musicEnabled => _musicEnabled;

  bool get vibrationEnabled => _vibrationEnabled;

  double get bgmVolume => _bgmVolume;

  double get sfxVolume => _sfxVolume;

  set soundEffectsEnabled(bool value) {
    if (_soundEffectsEnabled == value) {
      return;
    }
    _soundEffectsEnabled = value;
    if (!value) {
      _sfxVolume = 0;
    } else if (_sfxVolume == 0) {
      _sfxVolume = AppSettingsDefaults.sfxVolume;
    }
    notifyListeners();
    final store = _prefs;
    if (store != null) {
      unawaited(store.setSoundEffectsEnabled(value));
      unawaited(store.setSfxVolume(_sfxVolume));
    }
  }

  set musicEnabled(bool value) {
    if (_musicEnabled == value) {
      return;
    }
    _musicEnabled = value;
    if (!value) {
      _bgmVolume = 0;
    } else if (_bgmVolume == 0) {
      _bgmVolume = AppSettingsDefaults.bgmVolume;
    }
    notifyListeners();
    final store = _prefs;
    if (store != null) {
      unawaited(store.setMusicEnabled(value));
      unawaited(store.setBgmVolume(_bgmVolume));
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

  /// Updates BGM level (0–1). Zero mutes music. Persists when [persist] is true.
  void setBgmVolume(double value, {bool persist = true}) {
    _applyVolume(
      clamped: _clampVolume(value),
      currentVolume: _bgmVolume,
      isEnabled: () => _musicEnabled,
      setEnabled: (enabled) => _musicEnabled = enabled,
      setVolume: (volume) => _bgmVolume = volume,
      persistVolume: _prefs?.setBgmVolume,
      persistEnabled: _prefs?.setMusicEnabled,
      persist: persist,
    );
  }

  /// Updates SFX level (0–1). Zero mutes effects. Persists when [persist] is true.
  void setSfxVolume(double value, {bool persist = true}) {
    _applyVolume(
      clamped: _clampVolume(value),
      currentVolume: _sfxVolume,
      isEnabled: () => _soundEffectsEnabled,
      setEnabled: (enabled) => _soundEffectsEnabled = enabled,
      setVolume: (volume) => _sfxVolume = volume,
      persistVolume: _prefs?.setSfxVolume,
      persistEnabled: _prefs?.setSoundEffectsEnabled,
      persist: persist,
    );
  }

  void _applyVolume({
    required double clamped,
    required double currentVolume,
    required bool Function() isEnabled,
    required void Function(bool enabled) setEnabled,
    required void Function(double volume) setVolume,
    required Future<void> Function(double volume)? persistVolume,
    required Future<void> Function(bool enabled)? persistEnabled,
    required bool persist,
  }) {
    final enabled = clamped > 0;
    final volumeChanged = (currentVolume - clamped).abs() >= 0.001;
    final enabledChanged = isEnabled() != enabled;
    if (!volumeChanged && !enabledChanged) {
      return;
    }

    setVolume(clamped);
    setEnabled(enabled);
    notifyListeners();

    if (!persist) {
      return;
    }
    final storeVolume = persistVolume;
    final storeEnabled = persistEnabled;
    if (storeVolume != null) {
      unawaited(storeVolume(clamped));
    }
    if (storeEnabled != null) {
      unawaited(storeEnabled(enabled));
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
