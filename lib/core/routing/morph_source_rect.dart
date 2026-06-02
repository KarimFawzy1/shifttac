import 'package:flutter/widgets.dart';

/// Measures a widget's bounds in global coordinates for morph transitions.
class MorphSourceRect {
  MorphSourceRect._();

  /// Returns the [GlobalKey]'s widget bounds in screen space, or `null` if
  /// the key is unattached or not laid out.
  static Rect? tryMeasure(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) {
      return null;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    final offset = renderObject.localToGlobal(Offset.zero);
    return offset & renderObject.size;
  }
}
