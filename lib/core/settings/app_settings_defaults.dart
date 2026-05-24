/// Default audio levels used before the user changes volume in Settings.
abstract final class AppSettingsDefaults {
  AppSettingsDefaults._();

  static const double bgmVolume = 1;
  static const double sfxVolume = 0.8;
  static const double swipeSfxVolume = 0.8;

  /// Volume slider step (10%).
  static const double volumeStep = 0.1;

  static double snapVolume(double value) {
    final steps = (value / volumeStep).round();
    return (steps * volumeStep).clamp(0.0, 1.0);
  }
}
