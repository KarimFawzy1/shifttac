import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/routing/morph_route_config.dart';
import 'package:shifttac/core/routing/morph_shape.dart';

void main() {
  const source = Rect.fromLTWH(24, 200, 320, 120);
  const screen = Size(400, 800);
  const radius = 12.0;
  const config = MorphRouteConfig();

  group('MorphShape.interpolate', () {
    test('forward start keeps source card radius', () {
      final rrect = MorphShape.interpolate(
        sourceRect: source,
        targetSize: screen,
        positionProgress: 0,
        sourceBorderRadius: radius,
        reversing: false,
        forwardRadiusSoftenInterval: config.forwardRadiusSoftenInterval,
        reverseRadiusGrowInterval: config.reverseRadiusGrowInterval,
      );

      expect(rrect.tlRadiusX, radius);
      expect(rrect.width, source.width);
    });

    test('forward end is full screen with square corners', () {
      final rrect = MorphShape.interpolate(
        sourceRect: source,
        targetSize: screen,
        positionProgress: 1,
        sourceBorderRadius: radius,
        reversing: false,
        forwardRadiusSoftenInterval: config.forwardRadiusSoftenInterval,
        reverseRadiusGrowInterval: config.reverseRadiusGrowInterval,
      );

      expect(rrect.width, screen.width);
      expect(rrect.tlRadiusX, 0);
    });

    test('forward early frames keep card radius while bounds grow', () {
      final rrect = MorphShape.interpolate(
        sourceRect: source,
        targetSize: screen,
        positionProgress: 0.08,
        sourceBorderRadius: radius,
        reversing: false,
        forwardRadiusSoftenInterval: config.forwardRadiusSoftenInterval,
        reverseRadiusGrowInterval: config.reverseRadiusGrowInterval,
      );

      expect(rrect.width, greaterThan(source.width));
      expect(rrect.tlRadiusX, radius);
    });

    test('reverse start grows corners immediately while still large', () {
      final rrect = MorphShape.interpolate(
        sourceRect: source,
        targetSize: screen,
        positionProgress: 0.92,
        sourceBorderRadius: radius,
        reversing: true,
        forwardRadiusSoftenInterval: config.forwardRadiusSoftenInterval,
        reverseRadiusGrowInterval: config.reverseRadiusGrowInterval,
      );

      expect(rrect.width, greaterThan(source.width));
      expect(rrect.tlRadiusX, greaterThan(0));
    });

    test('reverse end restores source card radius', () {
      final rrect = MorphShape.interpolate(
        sourceRect: source,
        targetSize: screen,
        positionProgress: 0,
        sourceBorderRadius: radius,
        reversing: true,
        forwardRadiusSoftenInterval: config.forwardRadiusSoftenInterval,
        reverseRadiusGrowInterval: config.reverseRadiusGrowInterval,
      );

      expect(rrect.tlRadiusX, radius);
      expect(rrect.width, source.width);
    });

    test('reverse late collapse approaches full card radius', () {
      final rrect = MorphShape.interpolate(
        sourceRect: source,
        targetSize: screen,
        positionProgress: 0.12,
        sourceBorderRadius: radius,
        reversing: true,
        forwardRadiusSoftenInterval: config.forwardRadiusSoftenInterval,
        reverseRadiusGrowInterval: config.reverseRadiusGrowInterval,
      );

      expect(rrect.tlRadiusX, greaterThan(lerpDouble(0, radius, 0.5)!));
    });
  });
}
