import 'package:flutter/material.dart';

import '../../features/game/domain/models/game_mode.dart';
import '../../features/game/domain/models/game_session_config.dart';
import '../../features/game/presentation/screens/gameplay_screen.dart';
import '../../features/home/presentation/screens/main_shell_screen.dart';
import '../../features/how_to_play/presentation/screens/how_to_play_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/tiki_taka/presentation/screens/tiki_attribute_gallery_screen.dart';
import '../../features/tiki_taka/presentation/screens/tiki_taka_entry_screen.dart';
import '../launch/app_launch_gate.dart';
import 'app_routes.dart';
import 'main_shell_tab.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final builder = pageBuilderFor(settings);
    if (builder == null) {
      return null;
    }
    return MaterialPageRoute<void>(
      settings: settings,
      builder: builder,
    );
  }

  /// Returns the destination widget builder for [settings.name], or `null` if
  /// the route is not registered.
  ///
  /// Shared by [onGenerateRoute] and [MorphNavigator.pushNamedFrom].
  static WidgetBuilder? pageBuilderFor(RouteSettings settings) {
    final name = settings.name ?? AppRoutes.launch;

    if (name == AppRoutes.launch || name == '/') {
      return (_) => const AppLaunchGate();
    }

    if (name == AppRoutes.splash) {
      return (_) => const SplashScreen();
    }

    if (name == AppRoutes.onboarding) {
      return (_) => const OnboardingScreen();
    }

    if (name == AppRoutes.game) {
      final session = sessionFromRouteArguments(settings.arguments);
      return (_) => GameplayScreen(session: session);
    }

    if (name == AppRoutes.tikiTaka) {
      return (_) => const TikiTakaEntryScreen();
    }

    if (name == AppRoutes.tikiAttributeGallery) {
      return (_) => const TikiAttributeGalleryScreen();
    }

    if (name == AppRoutes.home) {
      final initialTab =
          _tabFromArguments(settings.arguments) ?? MainShellTab.home;
      return (_) => MainShellScreen(initialTab: initialTab);
    }

    if (name == AppRoutes.howToPlay) {
      return (_) => const HowToPlayScreen(standalone: true);
    }

    if (name == AppRoutes.settings) {
      return (_) => const SettingsScreen(standalone: true);
    }

    return null;
  }

  /// Resolves gameplay session from [RouteSettings.arguments]; defaults to ShiftTac.
  static GameSessionConfig sessionFromRouteArguments(Object? arguments) {
    if (arguments is GameSessionConfig) {
      return arguments;
    }
    if (arguments is GameMode) {
      return GameSessionConfig(mode: arguments);
    }
    return const GameSessionConfig.shift();
  }

  /// Resolves gameplay mode from [RouteSettings.arguments]; defaults to ShiftTac.
  static GameMode gameModeFromRouteArguments(Object? arguments) {
    return sessionFromRouteArguments(arguments).mode;
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
