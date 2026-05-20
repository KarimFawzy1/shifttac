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
    widget.settings.addListener(_onSettingsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.audio.onAppLifecycleState(AppLifecycleState.resumed);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.settings.removeListener(_onSettingsChanged);
    widget.audio.dispose();
    widget.settings.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    widget.audio.onSettingsChanged();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.audio.onAppLifecycleState(state);
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
