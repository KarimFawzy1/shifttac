import 'package:flutter/material.dart';

extension BuildContextThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);

  TextTheme get textStyles => theme.textTheme;

  ColorScheme get colors => theme.colorScheme;
}
