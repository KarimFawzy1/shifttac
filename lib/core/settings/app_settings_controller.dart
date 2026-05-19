import 'package:flutter/widgets.dart';

/// In-memory app preferences (no persistence in MVP).
///
/// Single instance is provided at the app root via [AppSettingsScope].
class AppSettingsController extends ChangeNotifier {
  AppSettingsController({
    bool soundEffectsEnabled = true,
    bool musicEnabled = true,
    bool vibrationEnabled = true,
  })  : _soundEffectsEnabled = soundEffectsEnabled,
        _musicEnabled = musicEnabled,
        _vibrationEnabled = vibrationEnabled;

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
  }

  set musicEnabled(bool value) {
    if (_musicEnabled == value) {
      return;
    }
    _musicEnabled = value;
    notifyListeners();
  }

  set vibrationEnabled(bool value) {
    if (_vibrationEnabled == value) {
      return;
    }
    _vibrationEnabled = value;
    notifyListeners();
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
