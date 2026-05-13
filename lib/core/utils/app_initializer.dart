import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_constants.dart';

class AppInitializer {
  AppInitializer._();

  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    await _applyPreferredOrientationsForFormFactor();
  }

  static Future<void> _applyPreferredOrientationsForFormFactor() async {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final logicalSize = view.physicalSize / view.devicePixelRatio;
    final isTablet =
        logicalSize.shortestSide >= AppConstants.tabletShortestSideBreakpoint;

    await SystemChrome.setPreferredOrientations(
      isTablet ? _tabletOrientations : _phoneOrientations,
    );
  }

  static const List<DeviceOrientation> _phoneOrientations = [
    DeviceOrientation.portraitUp,
  ];

  static const List<DeviceOrientation> _tabletOrientations = [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];
}
