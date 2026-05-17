import 'package:flutter/material.dart';

import '../routing/app_routes.dart';
import '../theme/app_colors.dart';
import 'app_launch_prefs.dart';

/// Root launch resolver: returning users → `/home`; first-time users → `/splash`.
class AppLaunchGate extends StatefulWidget {
  const AppLaunchGate({super.key});

  @override
  State<AppLaunchGate> createState() => _AppLaunchGateState();
}

class _AppLaunchGateState extends State<AppLaunchGate> {
  final AppLaunchPrefs _prefs = AppLaunchPrefs();

  @override
  void initState() {
    super.initState();
    _resolveLaunchRoute();
  }

  Future<void> _resolveLaunchRoute() async {
    final completed = await _prefs.hasCompletedOnboarding();
    if (!mounted) return;

    final destination =
        completed ? AppRoutes.home : AppRoutes.splash;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(destination);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.warmIvory,
      body: SizedBox.expand(),
    );
  }
}
