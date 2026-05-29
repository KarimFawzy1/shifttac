import 'package:flutter/material.dart';

import '../../features/game/domain/models/game_mode.dart';
import '../../features/game/presentation/screens/gameplay_screen.dart';
import '../../features/home/presentation/screens/main_shell_screen.dart';
import '../../features/how_to_play/presentation/screens/how_to_play_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../launch/app_launch_gate.dart';
import 'app_routes.dart';
import 'main_shell_tab.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? AppRoutes.launch;

    if (name == AppRoutes.launch || name == '/') {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const AppLaunchGate(),
      );
    }

    if (name == AppRoutes.splash) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const SplashScreen(),
      );
    }

    if (name == AppRoutes.onboarding) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const OnboardingScreen(),
      );
    }

    if (name == AppRoutes.game) {
      final mode = gameModeFromRouteArguments(settings.arguments);
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => GameplayScreen(mode: mode),
      );
    }

    if (name == AppRoutes.home) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => MainShellScreen(
          initialTab: _tabFromArguments(settings.arguments) ?? MainShellTab.home,
        ),
      );
    }

    if (name == AppRoutes.howToPlay) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const HowToPlayScreen(standalone: true),
      );
    }

    if (name == AppRoutes.settings) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const SettingsScreen(standalone: true),
      );
    }

    return null;
  }

  /// Resolves gameplay mode from [RouteSettings.arguments]; defaults to ShiftTac.
  static GameMode gameModeFromRouteArguments(Object? arguments) {
    if (arguments is GameMode) {
      return arguments;
    }
    return GameMode.shift;
  }

  static MainShellTab? _tabFromArguments(Object? arguments) {
    if (arguments is MainShellTab) {
      return arguments;
    }
    if (arguments is int) {
      return MainShellTab.fromIndex(arguments);
    }
    return null;
  }
}
