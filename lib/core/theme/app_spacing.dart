import 'package:flutter/material.dart';

/// Spacing and corner radii from `docs/design.md` frontmatter (`spacing:`,
/// `rounded:`). Assumes `1rem` = 16 logical pixels for rem → dp conversion.
class AppSpacing {
  AppSpacing._();

  static const double unit = 4;
  static const double containerPadding = 24;
  static const double gridGutter = 12;
  static const double stackSm = 8;
  static const double stackMd = 16;
  static const double stackLg = 32;

  static const double radiusSm = 4;
  static const double radiusDefault = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
  static const double radiusFull = 9999;

  static BorderRadius get borderRadiusSm => BorderRadius.circular(radiusSm);
  static BorderRadius get borderRadiusDefault =>
      BorderRadius.circular(radiusDefault);
  static BorderRadius get borderRadiusMd => BorderRadius.circular(radiusMd);
  static BorderRadius get borderRadiusLg => BorderRadius.circular(radiusLg);
  static BorderRadius get borderRadiusXl => BorderRadius.circular(radiusXl);
  static BorderRadius get borderRadiusFull => BorderRadius.circular(radiusFull);
}
