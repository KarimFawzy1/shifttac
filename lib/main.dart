import 'package:flutter/material.dart';

import 'app.dart';
import 'core/settings/app_settings_controller.dart';
import 'core/utils/app_initializer.dart';

Future<void> main() async {
  await AppInitializer.initialize();
  final settings = await AppSettingsController.load();
  runApp(ShiftTacApp(settings: settings));
}
