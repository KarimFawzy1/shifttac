import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Debug-only tracing for morph route pushes (minimal by default).
class MorphRouteDebug {
  MorphRouteDebug._();

  /// Set true locally when diagnosing morph timing; keeps log quota down.
  static const bool verbose = false;

  static const int _stallLogThresholdMs = 48;

  static int _pushSerial = 0;

  static int beginPush() {
    if (!kDebugMode) return 0;
    return ++_pushSerial;
  }

  static void logPushContext({
    required int pushSerial,
    required BuildContext context,
    required Duration transitionDuration,
    required bool reducedMotion,
  }) {
    if (!kDebugMode || !verbose) return;
    final route = ModalRoute.of(context);
    final hostAnim = route?.animation;
    debugPrint(
      '[MorphRoute] push#$pushSerial context '
      'hostRoute=${route?.settings.name ?? route.runtimeType} '
      'hostAnim=${hostAnim?.status}@${hostAnim?.value.toStringAsFixed(3)} '
      'transDur=${transitionDuration.inMilliseconds}ms',
    );
  }

  static void logRouteAnimationSnapshot({
    required int pushSerial,
    required String label,
    required double value,
    required AnimationStatus status,
  }) {
    if (!kDebugMode || !verbose) return;
    debugPrint(
      '[MorphRoute] push#$pushSerial $label '
      'status=$status value=${value.toStringAsFixed(3)}',
    );
  }

  static void logBuildTransitions({
    required int pushSerial,
    required double rawValue,
    required double curvedValue,
    required AnimationStatus status,
    required int buildCount,
  }) {
    if (!kDebugMode || !verbose) return;
    if (buildCount > 4) return;
    debugPrint(
      '[MorphRoute] push#$pushSerial build#$buildCount '
      'curved=${curvedValue.toStringAsFixed(3)}',
    );
  }

  static void logMorphProgress({
    required int pushSerial,
    required double linearT,
    required double routeValue,
    required int rawFrameDeltaMs,
  }) {
    if (!kDebugMode) return;
    if (!verbose && rawFrameDeltaMs < _stallLogThresholdMs && rawFrameDeltaMs != 0) {
      return;
    }
    debugPrint(
      '[MorphRoute] push#$pushSerial t=${linearT.toStringAsFixed(2)} '
      'route=${routeValue.toStringAsFixed(2)} deltaMs=$rawFrameDeltaMs',
    );
  }

  static void logCappedFrameDelta({
    required int pushSerial,
    required int rawMs,
  }) {
    if (!kDebugMode || rawMs < _stallLogThresholdMs) return;
    debugPrint(
      '[MorphRoute] push#$pushSerial stall ${rawMs}ms (reverse cap '
      '${_stallLogThresholdMs}ms/frame)',
    );
  }
}
