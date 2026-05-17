import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/constants/app_constants.dart';
import 'core/launch/app_launch_gate.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

class ShiftTacApp extends StatelessWidget {
  const ShiftTacApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
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
    );
  }
}
