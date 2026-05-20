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
  AppAudio(this._settings) : _lastMusicEnabled = _settings.musicEnabled {
    _settings.addListener(_onSettingsChanged);
    _bgmStateSub = _bgmPlayer.onPlayerStateChanged.listen(_onBgmStateChanged);
  }

  final AppSettingsController _settings;
  final AudioPlayer _bgmPlayer = AudioPlayer(playerId: 'shifttac_bgm');
  final Map<String, AudioPool> _sfxPools = {};

  static const double _bgmVolume = 0.38;
  static const double _sfxVolume = 0.85;

  bool _foreground = true;
  bool _disposing = false;
  bool _configured = false;
  bool _bgmPausedByApp = false;
  bool _sfxInFlight = false;
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
    await Future.wait(_sfxPools.values.map((pool) => pool.dispose()));
    _sfxPools.clear();
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
    if (_disposing ||
        _bgmPausedByApp ||
        !_settings.musicEnabled ||
        !_foreground) {
      return;
    }
    if (state == PlayerState.stopped || state == PlayerState.completed) {
      unawaited(startMusic());
    }
  }

  Future<void> _ensureConfigured() async {
    if (_configured) {
      return;
    }
    final bgmContext = AudioContextConfig(
      focus: AudioContextConfigFocus.gain,
    ).build();
    final sfxContext = _sfxContext();

    await _bgmPlayer.setAudioContext(bgmContext);
    _sfxPools
      ..clear()
      ..addAll({
        SoundAssets.tap: await _createSfxPool(SoundAssets.tap, sfxContext),
        SoundAssets.wrongTap: await _createSfxPool(
          SoundAssets.wrongTap,
          sfxContext,
        ),
        SoundAssets.restart: await _createSfxPool(
          SoundAssets.restart,
          sfxContext,
        ),
        SoundAssets.win: await _createSfxPool(SoundAssets.win, sfxContext),
      });
    _configured = true;
  }

  AudioContext _sfxContext() {
    return AudioContextConfig(
      focus: AudioContextConfigFocus.mixWithOthers,
    ).build();
  }

  Future<AudioPool> _createSfxPool(
    String assetPath,
    AudioContext audioContext,
  ) {
    return AudioPool.create(
      source: AssetSource(assetPath),
      minPlayers: 1,
      maxPlayers: 2,
      audioContext: audioContext,
    );
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
    await _ensureConfigured();
    _bgmPausedByApp = false;
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.setVolume(_bgmVolume);

    final state = _bgmPlayer.state;
    if (state == PlayerState.playing) {
      return;
    }
    if (state == PlayerState.paused) {
      await _safeAudioCall(_bgmPlayer.resume);
      return;
    }

    await _safeAudioCall(
      () => _bgmPlayer.play(AssetSource(SoundAssets.backgroundMusic)),
    );
  }

  Future<void> pauseMusic() async {
    if (_disposing) {
      return;
    }
    _bgmPausedByApp = true;
    if (_bgmPlayer.state == PlayerState.playing ||
        _bgmPlayer.state == PlayerState.paused) {
      await _safeAudioCall(_bgmPlayer.pause);
    }
  }

  Future<void> stopMusic() async {
    if (_disposing) {
      return;
    }
    _bgmPausedByApp = true;
    await _safeAudioCall(_bgmPlayer.stop);
  }

  Future<void> playTap() => _playSfx(SoundAssets.tap);

  Future<void> playWrongTap() => _playSfx(SoundAssets.wrongTap);

  Future<void> playRestart() => _playSfx(SoundAssets.restart);

  Future<void> playWin() => _playSfx(SoundAssets.win);

  Future<void> _playSfx(String assetPath) async {
    if (_disposing ||
        !_foreground ||
        !_settings.soundEffectsEnabled ||
        _sfxInFlight) {
      return;
    }
    _sfxInFlight = true;
    try {
      await _ensureConfigured();
      final pool = _sfxPools[assetPath];
      if (pool == null) {
        return;
      }
      await _safeAudioCall(() async {
        await pool.start(volume: _sfxVolume);
      });
      unawaited(_ensureBgmAfterSfx());
    } finally {
      _sfxInFlight = false;
    }
  }

  /// Safety net when platform audio focus briefly drops BGM during a one-shot SFX.
  Future<void> _ensureBgmAfterSfx() async {
    if (_disposing ||
        !_foreground ||
        !_settings.musicEnabled ||
        _bgmPausedByApp) {
      return;
    }
    final state = _bgmPlayer.state;
    if (state == PlayerState.playing) {
      return;
    }
    if (state == PlayerState.paused) {
      _bgmPausedByApp = false;
      await _safeAudioCall(_bgmPlayer.resume);
      return;
    }
    await startMusic();
  }

  Future<bool> _safeAudioCall(Future<void> Function() operation) async {
    try {
      await operation().timeout(const Duration(seconds: 3));
      return true;
    } on TimeoutException {
      // Native players can occasionally hang on Android. Keep the UI alive and
      // let the next settings/lifecycle transition retry playback.
      return false;
    } catch (_) {
      // Audio should never take down the app; failed one-shots are disposable.
      return false;
    }
  }
}

/// Exposes the root [AppAudio] to the widget tree.
class AppAudioScope extends InheritedWidget {
  const AppAudioScope({super.key, required this.audio, required super.child});

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
  bool updateShouldNotify(AppAudioScope oldWidget) => oldWidget.audio != audio;
}
