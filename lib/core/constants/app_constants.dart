import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  /// Shortest logical side (dp) at or above this is treated as a tablet for
  /// orientation and similar layout decisions (Material breakpoint).
  static const double tabletShortestSideBreakpoint = 600;

  static const String appName = 'ShiftTac';
  static const String appVersionLabel = '1.0.0';
  static const Size designSize = Size(390, 844);

  /// Minimum time splash is shown before tap-to-continue is accepted.
  static const Duration splashMinDisplayDuration = Duration(milliseconds: 2500);

  /// One half-cycle of the splash tap-icon breathe scale animation.
  static const Duration splashTapBreatheDuration = Duration(milliseconds: 5000);
}
