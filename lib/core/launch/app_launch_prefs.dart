import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the user has finished first-launch onboarding (D1).
class AppLaunchPrefs {
  AppLaunchPrefs({SharedPreferences? prefs}) : _prefs = prefs;

  static const String hasCompletedOnboardingKey = 'hasCompletedOnboarding';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<bool> hasCompletedOnboarding() async {
    final prefs = await _instance;
    return prefs.getBool(hasCompletedOnboardingKey) ?? false;
  }

  Future<void> markOnboardingCompleted() async {
    final prefs = await _instance;
    await prefs.setBool(hasCompletedOnboardingKey, true);
  }
}
