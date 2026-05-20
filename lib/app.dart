import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/audio/app_audio.dart';
import 'core/constants/app_constants.dart';
import 'core/launch/app_launch_gate.dart';
import 'core/routing/app_router.dart';
import 'core/settings/app_settings_controller.dart';
import 'core/theme/app_theme.dart';

class ShiftTacApp extends StatefulWidget {
  const ShiftTacApp({
    super.key,
    required this.settings,
    required this.audio,
  });

  final AppSettingsController settings;
  final AppAudio audio;

  @override
  State<ShiftTacApp> createState() => _ShiftTacAppState();
}

class _ShiftTacAppState extends State<ShiftTacApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.audio.initialize());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.audio.dispose());
    widget.settings.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        widget.audio.setForeground(true);
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        widget.audio.setForeground(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      settings: widget.settings,
      child: AppAudioScope(
        audio: widget.audio,
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
      ),
    );
  }
}
