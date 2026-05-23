import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/audio/app_audio.dart';
import 'core/settings/app_settings_controller.dart';
import 'core/utils/app_initializer.dart';

Future<void> main() async {
  await AppInitializer.initialize();
  final settings = await AppSettingsController.load();
  final audio = AppAudio(settings);
  unawaited(audio.initialize());
  runApp(ShiftTacApp(settings: settings, audio: audio));
}
