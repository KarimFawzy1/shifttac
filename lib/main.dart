import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'core/audio/app_audio.dart';
import 'core/debug/startup_timing_log.dart';
import 'core/settings/app_settings_controller.dart';
import 'core/utils/app_initializer.dart';

Future<void> main() async {
  StartupTimingLog.markAppStart();
  await AppInitializer.initialize();
  GoogleFonts.config.allowRuntimeFetching = false;
  final settings = await AppSettingsController.load();
  final audio = AppAudio(settings);
  unawaited(audio.initialize());
  runApp(ShiftTacApp(settings: settings, audio: audio));
}
