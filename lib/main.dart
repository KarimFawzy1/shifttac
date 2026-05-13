import 'package:flutter/material.dart';

import 'app.dart';
import 'core/utils/app_initializer.dart';

Future<void> main() async {
  await AppInitializer.initialize();
  runApp(const ShiftTacApp());
}
