import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

import '../settings/app_settings_controller.dart';

/// Bundled sound paths (relative to `assets/` per [AssetSource]).
abstract final class AppAudioAssets {
  AppAudioAssets._();

  static const String tap = 'sounds/tap.wav';
  static const String wrongTap = 'sounds/wrong-tap.wav';
  static const String restart = 'sounds/restart.wav';
  static const String win = 'sounds/win.wav';
  static const String lose = 'sounds/lose.wav';
  static const String background = 'sounds/background.mp3';
}

/// SFX + BGM; mute flags live only on [AppSettingsController].
class AppAudio {
  AppAudio({required AppSettingsController settings})
      : _settings = settings {
    _bgmPlayer = AudioPlayer(playerId: 'bgm');
    _sfxPlayer = AudioPlayer(playerId: 'sfx');
    unawaited(_bgmPlayer.setReleaseMode(ReleaseMode.loop));
    unawaited(_bgmPlayer.setVolume(_bgmVolume));
    unawaited(_sfxPlayer.setVolume(_sfxVolume));
  }

  static const double _bgmVolume = 0.35;
  static const double _sfxVolume = 0.7;

  final AppSettingsController _settings;
  late final AudioPlayer _bgmPlayer;
  late final AudioPlayer _sfxPlayer;

  bool _appInForeground = true;
  bool _bgmStarted = false;

  bool get _mayPlaySfx =>
      _appInForeground && _settings.soundEffectsEnabled;

  bool get _mayPlayBgm => _appInForeground && _settings.musicEnabled;

  void onSettingsChanged() {
    if (_mayPlayBgm) {
      unawaited(startMusic());
    } else {
      unawaited(stopMusic());
    }
  }

  void onAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _appInForeground = true;
        onSettingsChanged();
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _appInForeground = false;
        unawaited(pauseMusic());
    }
  }

  Future<void> startMusic() async {
    if (!_mayPlayBgm) {
      return;
    }
    try {
      if (_bgmStarted) {
        await _bgmPlayer.resume();
        return;
      }
      await _bgmPlayer.play(AssetSource(AppAudioAssets.background));
      _bgmStarted = true;
    } on Object {
      _bgmStarted = false;
    }
  }

  Future<void> stopMusic() async {
    try {
      await _bgmPlayer.stop();
    } on Object {
      // Player may not be initialized yet.
    }
    _bgmStarted = false;
  }

  Future<void> pauseMusic() async {
    try {
      await _bgmPlayer.pause();
    } on Object {
      // Player may not be initialized yet.
    }
  }

  Future<void> playTap() => _playSfx(AppAudioAssets.tap);

  Future<void> playWrongTap() => _playSfx(AppAudioAssets.wrongTap);

  Future<void> playRestart() => _playSfx(AppAudioAssets.restart);

  Future<void> playWin() => _playSfx(AppAudioAssets.win);

  Future<void> playLose() => _playSfx(AppAudioAssets.lose);

  Future<void> _playSfx(String assetPath) async {
    if (!_mayPlaySfx) {
      return;
    }
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource(assetPath));
    } on Object {
      // Ignore playback errors (missing asset, unsupported platform, etc.).
    }
  }

  Future<void> dispose() async {
    await Future.wait([
      _bgmPlayer.dispose(),
      _sfxPlayer.dispose(),
    ]);
  }
}

/// Exposes root [AppAudio] to the widget tree.
class AppAudioScope extends InheritedWidget {
  const AppAudioScope({
    super.key,
    required this.audio,
    required super.child,
  });

  final AppAudio audio;

  static AppAudio of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppAudioScope>();
    assert(
      scope != null,
      'AppAudioScope not found. Wrap the app with AppAudioScope.',
    );
    return scope!.audio;
  }

  static AppAudio read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppAudioScope>();
    assert(
      scope != null,
      'AppAudioScope not found. Wrap the app with AppAudioScope.',
    );
    return scope!.audio;
  }

  @override
  bool updateShouldNotify(AppAudioScope oldWidget) =>
      oldWidget.audio != audio;
}

/// Settings row / switch tap feedback.
void playSettingsTapSound(BuildContext context) {
  unawaited(AppAudioScope.read(context).playTap());
}
