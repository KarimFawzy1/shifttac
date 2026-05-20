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
  AppAudio(this._settings)
      : _lastMusicEnabled = _settings.musicEnabled {
    _settings.addListener(_onSettingsChanged);
    _bgmStateSub = _bgmPlayer.onPlayerStateChanged.listen(_onBgmStateChanged);
  }

  final AppSettingsController _settings;
  final AudioPlayer _bgmPlayer = AudioPlayer(playerId: 'shifttac_bgm');
  final AudioPlayer _sfxPlayer = AudioPlayer(playerId: 'shifttac_sfx');

  static const double _bgmVolume = 0.38;
  static const double _sfxVolume = 0.85;

  bool _foreground = true;
  bool _disposing = false;
  bool _configured = false;
  bool _bgmPausedByApp = false;
  bool _lastMusicEnabled;

  late final StreamSubscription<PlayerState> _bgmStateSub;

  /// Call once after the app root is mounted to begin BGM if enabled.
  Future<void> initialize() async {
    await _ensureConfigured();
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
    await _bgmStateSub.cancel();
    await _bgmPlayer.dispose();
    await _sfxPlayer.dispose();
  }

  /// Music toggle only — sound-effects changes do not touch BGM.
  void _onSettingsChanged() {
    final music = _settings.musicEnabled;
    if (music == _lastMusicEnabled) {
      return;
    }
    _lastMusicEnabled = music;
    unawaited(_syncBgm());
  }

  void _onBgmStateChanged(PlayerState state) {
    if (_disposing || _bgmPausedByApp || !_settings.musicEnabled || !_foreground) {
      return;
    }
    if (state == PlayerState.stopped || state == PlayerState.completed) {
      unawaited(startMusic(forceRestart: true));
    }
  }

  Future<void> _ensureConfigured() async {
    if (_configured) {
      return;
    }
    final bgmContext = AudioContextConfig(
      focus: AudioContextConfigFocus.gain,
    ).build();
    final sfxContext = AudioContextConfig(
      focus: AudioContextConfigFocus.mixWithOthers,
    ).build();

    await _bgmPlayer.setAudioContext(bgmContext);
    await _sfxPlayer.setAudioContext(sfxContext);
    await _sfxPlayer.setReleaseMode(ReleaseMode.stop);
    await _sfxPlayer.setPlayerMode(PlayerMode.lowLatency);
    _configured = true;
  }

  Future<void> _syncBgm() async {
    if (_disposing) {
      return;
    }
    if (_foreground && _settings.musicEnabled) {
      await startMusic(forceRestart: true);
    } else {
      await pauseMusic();
    }
  }

  Future<void> startMusic({bool forceRestart = false}) async {
    if (_disposing || !_foreground || !_settings.musicEnabled) {
      return;
    }
    await _ensureConfigured();
    _bgmPausedByApp = false;
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.setVolume(_bgmVolume);

    final state = _bgmPlayer.state;
    if (!forceRestart && state == PlayerState.playing) {
      return;
    }
    if (!forceRestart && state == PlayerState.paused) {
      await _bgmPlayer.resume();
      return;
    }

    await _bgmPlayer.stop();
    await _bgmPlayer.play(AssetSource(SoundAssets.backgroundMusic));
  }

  Future<void> pauseMusic() async {
    if (_disposing) {
      return;
    }
    _bgmPausedByApp = true;
    if (_bgmPlayer.state == PlayerState.playing ||
        _bgmPlayer.state == PlayerState.paused) {
      await _bgmPlayer.pause();
    }
  }

  Future<void> stopMusic() async {
    if (_disposing) {
      return;
    }
    _bgmPausedByApp = true;
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
    await _ensureConfigured();
    await _sfxPlayer.setVolume(_sfxVolume);
    await _sfxPlayer.stop();
    await _sfxPlayer.play(AssetSource(assetPath));
    unawaited(_ensureBgmAfterSfx());
  }

  /// Safety net when platform audio focus briefly drops BGM during a one-shot SFX.
  Future<void> _ensureBgmAfterSfx() async {
    if (_disposing || !_foreground || !_settings.musicEnabled || _bgmPausedByApp) {
      return;
    }
    final state = _bgmPlayer.state;
    if (state == PlayerState.playing) {
      return;
    }
    if (state == PlayerState.paused) {
      _bgmPausedByApp = false;
      await _bgmPlayer.resume();
      return;
    }
    await startMusic(forceRestart: true);
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
