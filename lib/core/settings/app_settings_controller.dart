import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../features/game/domain/models/bot_difficulty.dart';
import '../../features/game/domain/models/game_mode.dart';
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
    GameMode aiGameMode = GameMode.shift,
    BotDifficulty aiDifficulty = BotDifficulty.easy,
    double? bgmVolumeBeforeMute,
    double? sfxVolumeBeforeMute,
    AppSettingsPrefs? prefs,
  }) : _prefs = prefs,
       _soundEffectsEnabled = soundEffectsEnabled,
       _musicEnabled = musicEnabled,
       _vibrationEnabled = vibrationEnabled,
       _bgmVolume = _clampVolume(bgmVolume),
       _sfxVolume = _clampVolume(sfxVolume),
       _aiGameMode = aiGameMode,
       _aiDifficulty = aiDifficulty,
       _bgmVolumeBeforeMute = _clampVolume(
         bgmVolumeBeforeMute ??
             (bgmVolume > 0 ? bgmVolume : AppSettingsDefaults.bgmVolume),
       ),
       _sfxVolumeBeforeMute = _clampVolume(
         sfxVolumeBeforeMute ??
             (sfxVolume > 0 ? sfxVolume : AppSettingsDefaults.sfxVolume),
       );

  /// Loads persisted settings before the first frame.
  static Future<AppSettingsController> load() async {
    final prefs = AppSettingsPrefs();
    final snapshot = await prefs.load();
    final bgmStored = _clampVolume(snapshot.bgmVolume);
    final sfxStored = _clampVolume(snapshot.sfxVolume);

    return AppSettingsController(
      prefs: prefs,
      soundEffectsEnabled: snapshot.soundEffectsEnabled,
      musicEnabled: snapshot.musicEnabled,
      vibrationEnabled: snapshot.vibrationEnabled,
      bgmVolume: _volumeForEnabled(
        enabled: snapshot.musicEnabled,
        stored: bgmStored,
        defaultVolume: AppSettingsDefaults.bgmVolume,
      ),
      sfxVolume: _volumeForEnabled(
        enabled: snapshot.soundEffectsEnabled,
        stored: sfxStored,
        defaultVolume: AppSettingsDefaults.sfxVolume,
      ),
      aiGameMode: snapshot.aiGameMode,
      aiDifficulty: snapshot.aiDifficulty,
      bgmVolumeBeforeMute: snapshot.musicEnabled
          ? null
          : (bgmStored > 0 ? bgmStored : AppSettingsDefaults.bgmVolume),
      sfxVolumeBeforeMute: snapshot.soundEffectsEnabled
          ? null
          : (sfxStored > 0 ? sfxStored : AppSettingsDefaults.sfxVolume),
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
  GameMode _aiGameMode;
  BotDifficulty _aiDifficulty;
  double _bgmVolumeBeforeMute;
  double _sfxVolumeBeforeMute;

  bool get soundEffectsEnabled => _soundEffectsEnabled;

  bool get musicEnabled => _musicEnabled;

  bool get vibrationEnabled => _vibrationEnabled;

  double get bgmVolume => _bgmVolume;

  double get sfxVolume => _sfxVolume;
  GameMode get aiGameMode => _aiGameMode;
  BotDifficulty get aiDifficulty => _aiDifficulty;

  void setAiGameMode(GameMode value) {
    if (_aiGameMode == value) {
      return;
    }
    _aiGameMode = value;
    notifyListeners();
    final store = _prefs;
    if (store != null) {
      unawaited(store.setAiGameMode(value));
    }
  }

  void setAiDifficulty(BotDifficulty value) {
    if (_aiDifficulty == value) {
      return;
    }
    _aiDifficulty = value;
    notifyListeners();
    final store = _prefs;
    if (store != null) {
      unawaited(store.setAiDifficulty(value));
    }
  }

  set soundEffectsEnabled(bool value) {
    if (_soundEffectsEnabled == value) {
      return;
    }
    _soundEffectsEnabled = value;
    if (!value) {
      if (_sfxVolume > 0) {
        _sfxVolumeBeforeMute = _sfxVolume;
      }
      _sfxVolume = 0;
    } else if (_sfxVolume == 0) {
      _sfxVolume = _sfxVolumeBeforeMute;
    }
    notifyListeners();
    final store = _prefs;
    if (store != null) {
      unawaited(store.setSoundEffectsEnabled(value));
      unawaited(store.setSfxVolume(value ? _sfxVolume : _sfxVolumeBeforeMute));
    }
  }

  set musicEnabled(bool value) {
    if (_musicEnabled == value) {
      return;
    }
    _musicEnabled = value;
    if (!value) {
      if (_bgmVolume > 0) {
        _bgmVolumeBeforeMute = _bgmVolume;
      }
      _bgmVolume = 0;
    } else if (_bgmVolume == 0) {
      _bgmVolume = _bgmVolumeBeforeMute;
    }
    notifyListeners();
    final store = _prefs;
    if (store != null) {
      unawaited(store.setMusicEnabled(value));
      unawaited(store.setBgmVolume(value ? _bgmVolume : _bgmVolumeBeforeMute));
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

  /// Updates BGM level (0–1). Zero mutes music.
  ///
  /// When [persist] is false (live slider drag), state updates without
  /// [notifyListeners]. Call again with [persist] true on release to refresh UI.
  void setBgmVolume(double value, {bool persist = true}) {
    _applyVolume(
      clamped: _clampVolume(value),
      currentVolume: _bgmVolume,
      isEnabled: () => _musicEnabled,
      setEnabled: (enabled) => _musicEnabled = enabled,
      setVolume: (volume) => _bgmVolume = volume,
      volumeBeforeMute: _bgmVolumeBeforeMute,
      setVolumeBeforeMute: (volume) => _bgmVolumeBeforeMute = volume,
      persistVolume: _prefs?.setBgmVolume,
      persistEnabled: _prefs?.setMusicEnabled,
      persist: persist,
    );
  }

  /// Updates SFX level (0–1). Zero mutes effects.
  ///
  /// When [persist] is false (live slider drag), state updates without
  /// [notifyListeners]. Call again with [persist] true on release to refresh UI.
  void setSfxVolume(double value, {bool persist = true}) {
    _applyVolume(
      clamped: _clampVolume(value),
      currentVolume: _sfxVolume,
      isEnabled: () => _soundEffectsEnabled,
      setEnabled: (enabled) => _soundEffectsEnabled = enabled,
      setVolume: (volume) => _sfxVolume = volume,
      volumeBeforeMute: _sfxVolumeBeforeMute,
      setVolumeBeforeMute: (volume) => _sfxVolumeBeforeMute = volume,
      persistVolume: _prefs?.setSfxVolume,
      persistEnabled: _prefs?.setSoundEffectsEnabled,
      persist: persist,
    );
  }

  /// Toggles SFX mute while preserving the last non-zero level for unmute.
  void toggleSfxMute() {
    if (_sfxVolume > 0) {
      setSfxVolume(0);
      return;
    }
    setSfxVolume(_sfxVolumeBeforeMute);
  }

  /// Toggles BGM mute while preserving the last non-zero level for unmute.
  void toggleBgmMute() {
    if (_bgmVolume > 0) {
      setBgmVolume(0);
      return;
    }
    setBgmVolume(_bgmVolumeBeforeMute);
  }

  void _applyVolume({
    required double clamped,
    required double currentVolume,
    required bool Function() isEnabled,
    required void Function(bool enabled) setEnabled,
    required void Function(double volume) setVolume,
    required double volumeBeforeMute,
    required void Function(double volume) setVolumeBeforeMute,
    required Future<void> Function(double volume)? persistVolume,
    required Future<void> Function(bool enabled)? persistEnabled,
    required bool persist,
  }) {
    final enabled = clamped > 0;
    final volumeChanged = (currentVolume - clamped).abs() >= 0.001;
    final enabledChanged = isEnabled() != enabled;
    final rememberedVolume = clamped > 0
        ? clamped
        : (currentVolume > 0 ? currentVolume : volumeBeforeMute);

    if (volumeChanged || enabledChanged) {
      if (clamped > 0) {
        setVolumeBeforeMute(clamped);
      } else if (currentVolume > 0) {
        setVolumeBeforeMute(currentVolume);
      }
      setVolume(clamped);
      setEnabled(enabled);
    }

    if (persist) {
      notifyListeners();
    }

    if (!persist) {
      return;
    }
    final storeVolume = persistVolume;
    final storeEnabled = persistEnabled;
    if (storeVolume != null) {
      unawaited(storeVolume(rememberedVolume));
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
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppSettingsScope>();
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
