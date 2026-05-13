import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/constants/app_constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _applyPreferredOrientationsForFormFactor();
  runApp(const ShiftTacApp());
}

Future<void> _applyPreferredOrientationsForFormFactor() async {
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final logicalSize = view.physicalSize / view.devicePixelRatio;
  final isTablet =
      logicalSize.shortestSide >= AppConstants.tabletShortestSideBreakpoint;

  if (isTablet) {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  } else {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
  }
}
