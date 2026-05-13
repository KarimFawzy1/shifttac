import 'package:flutter/material.dart';

import '../../features/game/presentation/screens/gameplay_screen.dart';
import '../../shared/widgets/infinity_logo.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_scaffold.dart';
import 'app_routes.dart';

// class AppRouter {
//   AppRouter._();

//   static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
//     final routeName = settings.name ?? AppRoutes.splash;

//     if (routeName == AppRoutes.game) {
//       return MaterialPageRoute<void>(
//         settings: settings,
//         builder: (_) => const GameplayScreen(),
//       );
//     }

//     return MaterialPageRoute<void>(
//       settings: settings,
//       builder: (_) => _PlaceholderScreen(routeName: routeName),
//     );
//   }
// }

class AppRouter {
  AppRouter._();

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    // Check if the route is the initial launch OR the explicit game route
    final name = settings.name;
    final isInitialOrGame =
        name == AppRoutes.game || name == '/' || name == AppRoutes.splash;

    if (isInitialOrGame) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const GameplayScreen(),
      );
    }

    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => _PlaceholderScreen(routeName: name ?? 'Unknown'),
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
            const InfinityLogo(),
            SizedBox(height: AppSpacing.stackMd),
            Text(routeName, style: AppTextStyles.titleMd),
          ],
        ),
      ),
    );
  }
}
