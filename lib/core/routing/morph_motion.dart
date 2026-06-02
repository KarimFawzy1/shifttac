import 'package:flutter/widgets.dart';

/// Accessibility helpers for morph navigation.
class MorphMotion {
  MorphMotion._();

  /// Whether the platform or user has requested reduced / disabled animations.
  static bool prefersReducedMotion(BuildContext context) {
    return MediaQuery.disableAnimationsOf(context);
  }
}
