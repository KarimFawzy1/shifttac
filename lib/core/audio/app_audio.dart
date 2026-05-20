import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

import '../settings/app_settings_controller.dart';

/// Bundled sound paths under `assets/sounds/` (pubspec asset folder).
abstract final class SoundAssets {
  SoundAssets._();

  static const tap = 'sounds/tap.wav';
  static const wrongTap = 'sounds/wrong-tap.wav';
  static const restart = 'sounds/restart.wav';
  static const win = 'sounds/win.wav';
  static const backgroundMusic = 'sounds/background.mp3';
}

/// SFX + app-wide BGM. Reads [AppSettingsController] — no parallel mute flags.
class AppAudio {
  AppAudio(this._settings) {
    _settings.addListener(_onSettingsChanged);
  }

  final AppSettingsController _settings;
  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  static const double _bgmVolume = 0.38;
  static const double _sfxVolume = 0.85;

  bool _foreground = true;
  bool _disposing = false;

  /// Call once after the app root is mounted to begin BGM if enabled.
  Future<void> initialize() async {
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _syncBgm();
  }

  void setForeground(bool inForeground) {
    _foreground = inForeground;
    if (inForeground) {
      unawaited(_syncBgm());
    } else {
      unawaited(pauseMusic());
    }
  }

  Future<void> dispose() async {
    _disposing = true;
    _settings.removeListener(_onSettingsChanged);
    await _bgmPlayer.dispose();
    await _sfxPlayer.dispose();
  }

  void _onSettingsChanged() {
    unawaited(_syncBgm());
  }

  Future<void> _syncBgm() async {
    if (_disposing) {
      return;
    }
    if (_foreground && _settings.musicEnabled) {
      await startMusic();
    } else {
      await pauseMusic();
    }
  }

  Future<void> startMusic() async {
    if (_disposing || !_foreground || !_settings.musicEnabled) {
      return;
    }
    await _bgmPlayer.setVolume(_bgmVolume);
    final state = _bgmPlayer.state;
    if (state == PlayerState.playing) {
      return;
    }
    if (state == PlayerState.paused) {
      await _bgmPlayer.resume();
      return;
    }
    await _bgmPlayer.play(AssetSource(SoundAssets.backgroundMusic));
  }

  Future<void> pauseMusic() async {
    if (_disposing) {
      return;
    }
    if (_bgmPlayer.state == PlayerState.playing) {
      await _bgmPlayer.pause();
    }
  }

  Future<void> stopMusic() async {
    if (_disposing) {
      return;
    }
    await _bgmPlayer.stop();
  }

  Future<void> playTap() => _playSfx(SoundAssets.tap);

  Future<void> playWrongTap() => _playSfx(SoundAssets.wrongTap);

  Future<void> playRestart() => _playSfx(SoundAssets.restart);

  Future<void> playWin() => _playSfx(SoundAssets.win);

  Future<void> _playSfx(String assetPath) async {
    if (_disposing || !_foreground || !_settings.soundEffectsEnabled) {
      return;
    }
    await _sfxPlayer.setVolume(_sfxVolume);
    await _sfxPlayer.play(AssetSource(assetPath));
  }
}

/// Exposes the root [AppAudio] to the widget tree.
class AppAudioScope extends InheritedWidget {
  const AppAudioScope({
    super.key,
    required this.audio,
    required super.child,
  });

  final AppAudio audio;

  static AppAudio read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppAudioScope>();
    assert(
      scope != null,
      'AppAudioScope not found. Wrap MaterialApp with AppAudioScope.',
    );
    return scope!.audio;
  }

  @override
  bool updateShouldNotify(AppAudioScope oldWidget) =>
      oldWidget.audio != audio;
}
