import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Visual and timing options for [MorphPageRoute].
class MorphRouteConfig {
  const MorphRouteConfig({
    this.forwardDuration = const Duration(milliseconds: 480),
    this.reverseDuration = const Duration(milliseconds: 340),
    this.positionCurve = Curves.easeOutCubic,
    this.reversePositionCurve = Curves.easeInCubic,
    this.contentRevealInterval = const Interval(0.35, 1.0, curve: Curves.easeOut),
    this.sourceBorderRadius = AppSpacing.radiusMd,
    this.surfaceColor,
    this.contentScaleBegin = 0.98,
  });

  final Duration forwardDuration;
  final Duration reverseDuration;
  final Curve positionCurve;
  final Curve reversePositionCurve;
  final Interval contentRevealInterval;
  final double sourceBorderRadius;
  final Color? surfaceColor;
  final double contentScaleBegin;
}
