import 'package:flutter/material.dart';

import '../../features/game/presentation/screens/gameplay_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../constants/image_constants.dart';
import '../launch/app_launch_gate.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_scaffold.dart';
import 'app_routes.dart';

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

    if (name == AppRoutes.game) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const GameplayScreen(),
      );
    }

    if (name == AppRoutes.home) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const HomeScreen(),
      );
    }

    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => _PlaceholderScreen(routeName: name),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.routeName});

  final String routeName;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              ImageConstant.logo,
              height: AppSpacing.stackLg * 2,
              fit: BoxFit.contain,
            ),
            SizedBox(height: AppSpacing.stackMd),
            Text(routeName, style: AppTextStyles.titleMd),
          ],
        ),
      ),
    );
  }
}
