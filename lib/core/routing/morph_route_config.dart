import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Visual and timing options for [MorphPageRoute].
///
/// Defaults align with [AppSpacing] radii and typical Material motion curves.
/// Call sites may override [surfaceColor] to match a source card (for example
/// [AppColors.primary] on the home hero card).
class MorphRouteConfig {
  const MorphRouteConfig({
    this.forwardDuration = const Duration(milliseconds: 460),
    this.reverseDuration = const Duration(milliseconds: 320),
    this.positionCurve = Curves.easeOutCubic,
    this.reversePositionCurve = Curves.easeInCubic,
    this.contentRevealInterval = const Interval(0.32, 1.0, curve: Curves.easeOut),
    this.reverseContentHideInterval = const Interval(0.0, 0.65, curve: Curves.easeIn),
    this.sourceBorderRadius = AppSpacing.radiusMd,
    this.surfaceColor,
    this.contentScaleBegin = 0.98,
    this.semanticRevealThreshold = 0.92,
  });

  final Duration forwardDuration;
  final Duration reverseDuration;
  final Curve positionCurve;
  final Curve reversePositionCurve;

  /// Forward content opacity / scale keyed to route progress `t` in `[0, 1]`.
  final Interval contentRevealInterval;

  /// Reverse content fade keyed to route progress `t` in `[0, 1]` (early hide).
  final Interval reverseContentHideInterval;

  final double sourceBorderRadius;
  final Color? surfaceColor;
  final double contentScaleBegin;

  /// Destination semantics are withheld until morph progress reaches this value.
  final double semanticRevealThreshold;
}
