import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

import '../settings/app_settings_controller.dart';

/// Bundled sound paths under `assets/sounds/` (pubspec asset folder).
abstract final class SoundAssets {
  SoundAssets._();

  static const tap = 'sounds/tap.wav';
  static const swipe = 'sounds/swipe.wav';
  static const wrongTap = 'sounds/wrong-tap.wav';
  static const restart = 'sounds/restart.wav';
  static const win = 'sounds/win.wav';
  static const lose = 'sounds/lose.wav';
  static const backgroundMusic = 'sounds/background.mp3';
}

/// SFX + app-wide BGM. Reads [AppSettingsController] — no parallel mute flags.
class AppAudio {
  AppAudio(this._settings) : _lastMusicEnabled = _settings.musicEnabled {
    _settings.addListener(_onSettingsChanged);
    _attachBgmStateListener();
  }

  final AppSettingsController _settings;
  AudioPlayer _bgmPlayer = AudioPlayer(playerId: 'shifttac_bgm_0');
  final Map<String, AudioPool> _sfxPools = {};

  static const double _bgmVolume = 1;
  static const double _sfxVolume = 0.8;
  static const double _swipeSfxVolume = 1;
  static const Duration _sfxRecycleDelay = Duration(milliseconds: 1500);

  bool _foreground = true;
  bool _disposing = false;
  bool _bgmConfigured = false;
  bool _bgmSourceReady = false;
  bool _sfxConfigured = false;
  bool _bgmPausedByApp = false;
  bool _lastMusicEnabled;
  int _bgmGeneration = 0;

  StreamSubscription<PlayerState>? _bgmStateSub;
  Future<void>? _initializeFuture;
  Future<void>? _sfxConfigureFuture;

  /// Warms BGM (and SFX pools in the background). Safe to call more than once.
  Future<void> initialize() {
    return _initializeFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    await _ensureBgmConfigured();
    await _preloadBgmSource();
    unawaited(_ensureSfxConfigured());
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
    await _bgmStateSub?.cancel();
    await _bgmPlayer.dispose();
    await Future.wait(_sfxPools.values.map((pool) => pool.dispose()));
    _sfxPools.clear();
  }

  void _attachBgmStateListener() {
    _bgmStateSub = _bgmPlayer.onPlayerStateChanged.listen(_onBgmStateChanged);
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

  Future<void> _ensureBgmConfigured() async {
    if (_bgmConfigured) {
      return;
    }
    final bgmContext = AudioContextConfig(
      focus: AudioContextConfigFocus.gain,
    ).build();

    await _bgmPlayer.setAudioContext(bgmContext);
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.setVolume(_bgmVolume);
    _bgmConfigured = true;
  }

  /// Loads the BGM asset ahead of [resume] so first playback is not blocked on I/O.
  Future<void> _preloadBgmSource() async {
    if (_disposing || _bgmSourceReady) {
      return;
    }
    final loaded = await _safeAudioCall(
      () => _bgmPlayer.setSource(AssetSource(SoundAssets.backgroundMusic)),
    );
    if (loaded) {
      _bgmSourceReady = true;
    }
  }

  Future<void> _ensureSfxConfigured() {
    if (_sfxConfigured) {
      return Future.value();
    }
    return _sfxConfigureFuture ??= _configureSfx();
  }

  Future<void> _configureSfx() async {
    try {
      final sfxContext = _sfxContext();
      const sfxAssets = [
        SoundAssets.tap,
        SoundAssets.swipe,
        SoundAssets.wrongTap,
        SoundAssets.restart,
        SoundAssets.win,
        SoundAssets.lose,
      ];
      final createdPools = await Future.wait(
        sfxAssets.map((path) => _createSfxPool(path, sfxContext)),
      );
      final pools = Map<String, AudioPool>.fromIterables(
        sfxAssets,
        createdPools,
      );

      if (_disposing) {
        await Future.wait(pools.values.map((pool) => pool.dispose()));
        return;
      }

      _sfxPools
        ..clear()
        ..addAll(pools);
      _sfxConfigured = true;
    } finally {
      _sfxConfigureFuture = null;
    }
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
      maxPlayers: 3,
      audioContext: audioContext,
      playerMode: PlayerMode.lowLatency,
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
    await _ensureBgmConfigured();
    _bgmPausedByApp = false;

    final state = _bgmPlayer.state;
    if (state == PlayerState.playing) {
      return;
    }
    if (state == PlayerState.paused) {
      await _safeAudioCall(_bgmPlayer.resume);
      return;
    }

    if (_bgmSourceReady) {
      await _safeAudioCall(_bgmPlayer.resume);
      return;
    }

    final played = await _safeAudioCall(
      () => _bgmPlayer.play(AssetSource(SoundAssets.backgroundMusic)),
    );
    if (played) {
      _bgmSourceReady = true;
    }
    if (!played && !_disposing && _foreground && _settings.musicEnabled) {
      await _recreateBgmPlayer();
      await _safeAudioCall(
        () => _bgmPlayer.play(AssetSource(SoundAssets.backgroundMusic)),
      );
    }
  }

  Future<void> _recreateBgmPlayer() async {
    final oldPlayer = _bgmPlayer;
    await _bgmStateSub?.cancel();
    _bgmGeneration++;
    _bgmPlayer = AudioPlayer(playerId: 'shifttac_bgm_$_bgmGeneration');
    _attachBgmStateListener();
    _bgmConfigured = false;
    _bgmSourceReady = false;
    await _ensureBgmConfigured();
    await _preloadBgmSource();
    try {
      await oldPlayer.dispose().timeout(const Duration(milliseconds: 500));
    } catch (_) {
      // A failed native MediaPlayer can hang on dispose; abandon it safely.
    }
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

  Future<void> playSwipe() => _playSfx(SoundAssets.swipe);

  Future<void> playWrongTap() => _playSfx(SoundAssets.wrongTap);

  Future<void> playRestart() => _playSfx(SoundAssets.restart);

  Future<void> playWin() => _playSfx(SoundAssets.win);

  Future<void> playLose() => _playSfx(SoundAssets.lose);

  Future<void> _playSfx(String assetPath) async {
    if (_disposing || !_foreground || !_settings.soundEffectsEnabled) {
      return;
    }
    await _ensureSfxConfigured();
    final pool = _sfxPools[assetPath];
    if (pool == null) {
      return;
    }

    final volume = assetPath == SoundAssets.swipe
        ? _swipeSfxVolume
        : _sfxVolume;
    final stop = await _safeAudioResult(() => pool.start(volume: volume));
    if (stop == null) {
      unawaited(_recreateSfxPool(assetPath));
      return;
    }

    unawaited(_recycleSfxPlayer(stop));
    unawaited(_ensureBgmAfterSfx());
  }

  Future<void> _recycleSfxPlayer(StopFunction stop) async {
    await Future<void>.delayed(_sfxRecycleDelay);
    if (!_disposing) {
      await _safeAudioCall(stop);
    }
  }

  Future<void> _recreateSfxPool(String assetPath) async {
    if (_disposing) {
      return;
    }
    final replacement = await _createSfxPool(assetPath, _sfxContext());
    final previous = _sfxPools[assetPath];
    _sfxPools[assetPath] = replacement;
    if (previous != null) {
      unawaited(_safeAudioCall(previous.dispose));
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
    final completed = await _safeAudioResult(() async {
      await operation();
      return true;
    });
    return completed ?? false;
  }

  Future<T?> _safeAudioResult<T>(Future<T> Function() operation) async {
    try {
      return await operation().timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // Native players can occasionally hang on Android. Keep the UI alive and
      // let the next settings/lifecycle transition retry playback.
      return null;
    } catch (_) {
      // Audio should never take down the app; failed one-shots are disposable.
      return null;
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
