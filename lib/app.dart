import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/constants/app_constants.dart';
import 'core/launch/app_launch_gate.dart';
import 'core/routing/app_router.dart';
import 'core/settings/app_settings_controller.dart';
import 'core/theme/app_theme.dart';

class ShiftTacApp extends StatefulWidget {
  const ShiftTacApp({super.key, required this.settings});

  final AppSettingsController settings;

  @override
  State<ShiftTacApp> createState() => _ShiftTacAppState();
}

class _ShiftTacAppState extends State<ShiftTacApp> {
  @override
  void dispose() {
    widget.settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      settings: widget.settings,
      child: ScreenUtilInit(
        designSize: AppConstants.designSize,
        minTextAdapt: true,
        builder: (context, child) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: const AppLaunchGate(),
            onGenerateRoute: AppRouter.onGenerateRoute,
          );
        },
      ),
    );
  }
}
