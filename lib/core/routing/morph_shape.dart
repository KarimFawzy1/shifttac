import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

/// Geometry helpers for [MorphPageRoute] shape interpolation.
class MorphShape {
  MorphShape._();

  /// Builds the morph silhouette: bounds follow [positionProgress], corners follow
  /// [sizeProgress] with separate forward/reverse timing so radius does not hit
  /// zero too early on expand or snap in at the end on collapse.
  static RRect interpolate({
    required Rect sourceRect,
    required Size targetSize,
    required double positionProgress,
    required double sourceBorderRadius,
    required bool reversing,
    required Interval forwardRadiusSoftenInterval,
    required Interval reverseRadiusGrowInterval,
  }) {
    final targetRect = Offset.zero & targetSize;
    final rect = Rect.lerp(sourceRect, targetRect, positionProgress)!;
    final sizeProgress = rectSizeProgress(
      current: rect,
      source: sourceRect,
      target: targetRect,
    );
    final radius = cornerRadius(
      positionProgress: positionProgress,
      sizeProgress: sizeProgress,
      sourceBorderRadius: sourceBorderRadius,
      reversing: reversing,
      forwardSoften: forwardRadiusSoftenInterval,
      reverseGrow: reverseRadiusGrowInterval,
      minSide: rect.shortestSide,
    );

    return RRect.fromRectAndRadius(rect, Radius.circular(radius));
  }

  /// How close [current] is to full screen, from card area to target area.
  static double rectSizeProgress({
    required Rect current,
    required Rect source,
    required Rect target,
  }) {
    final sourceArea = source.width * source.height;
    final targetArea = target.width * target.height;
    final currentArea = current.width * current.height;
    final range = targetArea - sourceArea;
    if (range <= 0) {
      return 1;
    }
    return ((currentArea - sourceArea) / range).clamp(0.0, 1.0);
  }

  static double cornerRadius({
    required double positionProgress,
    required double sizeProgress,
    required double sourceBorderRadius,
    required bool reversing,
    required Interval forwardSoften,
    required Interval reverseGrow,
    required double minSide,
  }) {
    final maxRadius = minSide / 2;
    final double radius;

    if (reversing) {
      if (positionProgress <= 0) {
        radius = sourceBorderRadius;
      } else {
        final shrink = (1 - sizeProgress).clamp(0.0, 1.0);
        final grow = reverseGrow.transform(shrink);
        radius = lerpDouble(0, sourceBorderRadius, grow)!;
      }
    } else if (positionProgress >= 1) {
      radius = 0;
    } else {
      final soften = forwardSoften.transform(sizeProgress);
      if (soften <= 0) {
        radius = sourceBorderRadius;
      } else {
        radius = lerpDouble(sourceBorderRadius, 0, soften)!;
      }
    }

    return radius.clamp(0, maxRadius);
  }

  /// Aligns full-screen destination content toward [sourceRect] during the morph.
  static Alignment contentAlignment(Rect sourceRect, Size screenSize) {
    final x = (sourceRect.center.dx / screenSize.width).clamp(0.0, 1.0);
    final y = (sourceRect.center.dy / screenSize.height).clamp(0.0, 1.0);
    return Alignment(x * 2 - 1, y * 2 - 1);
  }

  /// [RRect] expressed in the coordinate space of [Positioned] inside [outerRect].
  static RRect toLocalSpace(RRect rrect, Rect outerRect) {
    return rrect.shift(-outerRect.topLeft);
  }
}

/// Clips children to a morph [RRect] in local layout coordinates.
class MorphShapeClipper extends CustomClipper<Path> {
  MorphShapeClipper(this.rrect);

  final RRect rrect;

  @override
  Path getClip(Size size) => Path()..addRRect(rrect);

  @override
  bool shouldReclip(covariant MorphShapeClipper oldClipper) {
    return oldClipper.rrect != rrect;
  }
}
