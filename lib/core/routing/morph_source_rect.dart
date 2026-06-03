import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'morph_route_debug.dart';

/// Why [MorphSourceRect.resolveForMorph] could not read bounds.
enum MorphMeasureFailure {
  noContext,
  notRenderBox,
  noSize,
  emptyRect,
}

/// Measures a widget's bounds in global coordinates for morph transitions.
class MorphSourceRect {
  MorphSourceRect._();

  /// Returns the [GlobalKey]'s widget bounds in screen space, or `null` if
  /// the key is unattached or not laid out.
  static Rect? tryMeasure(GlobalKey key) => _tryMeasureDetailed(key).rect;

  /// Waits for layout (up to [maxFrames]) before giving up.
  ///
  /// On cold start the first tap can run before the card [RenderBox] has
  /// [hasSize]; without this, [MorphNavigator] falls back to [MaterialPageRoute].
  static Future<Rect?> resolveForMorph(
    GlobalKey key, {
    int maxFrames = 8,
  }) async {
    MorphMeasureFailure? lastFailure;
    for (var frame = 0; frame < maxFrames; frame++) {
      final result = _tryMeasureDetailed(key);
      if (result.rect != null) {
        _log('resolveForMorph ok frame=$frame rect=${result.rect}');
        return result.rect;
      }
      lastFailure = result.failure;
      await SchedulerBinding.instance.endOfFrame;
    }
    _log('resolveForMorph failed last=$lastFailure frames=$maxFrames');
    return null;
  }

  static ({Rect? rect, MorphMeasureFailure? failure}) _tryMeasureDetailed(
    GlobalKey key,
  ) {
    final context = key.currentContext;
    if (context == null) {
      return (rect: null, failure: MorphMeasureFailure.noContext);
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) {
      return (rect: null, failure: MorphMeasureFailure.notRenderBox);
    }
    if (!renderObject.hasSize) {
      return (rect: null, failure: MorphMeasureFailure.noSize);
    }
    final offset = renderObject.localToGlobal(Offset.zero);
    final rect = offset & renderObject.size;
    if (rect.width <= 0 || rect.height <= 0) {
      return (rect: null, failure: MorphMeasureFailure.emptyRect);
    }
    return (rect: rect, failure: null);
  }

  static void _log(String message) {
    if (kDebugMode && MorphRouteDebug.verbose) {
      debugPrint('[MorphNav] $message');
    }
  }
}
