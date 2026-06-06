import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../debug/startup_timing_log.dart';
import 'app_router.dart';
import 'morph_fade_page_route.dart';
import 'morph_motion.dart';
import 'morph_page_route.dart';
import 'morph_route_config.dart';
import 'morph_route_debug.dart';
import 'morph_source_rect.dart';

/// Pushes routes with an optional morph transition from a source widget.
class MorphNavigator {
  MorphNavigator._();

  /// Pushes a named route using [AppRouter.pageBuilderFor] and a morph transition
  /// when [sourceKey] can be measured.
  ///
  /// Falls back to [Navigator.pushNamed] when the route is unknown, or to a
  /// standard [MaterialPageRoute] when the source cannot be measured.
  static Future<T?> pushNamedFrom<T>({
    required BuildContext context,
    required GlobalKey sourceKey,
    required String routeName,
    Object? arguments,
    MorphRouteConfig config = const MorphRouteConfig(),
  }) {
    final settings = RouteSettings(name: routeName, arguments: arguments);
    final builder = AppRouter.pageBuilderFor(settings);
    if (builder == null) {
      return Navigator.of(context).pushNamed<T>(routeName, arguments: arguments);
    }
    return pushFrom<T>(
      context: context,
      sourceKey: sourceKey,
      builder: builder,
      settings: settings,
      config: config,
    );
  }

  /// Pushes [builder] using a morph transition when [sourceKey] can be measured.
  ///
  /// Falls back to a standard [MaterialPageRoute] when measurement fails.
  static Future<T?> pushFrom<T>({
    required BuildContext context,
    required GlobalKey sourceKey,
    required WidgetBuilder builder,
    RouteSettings? settings,
    MorphRouteConfig config = const MorphRouteConfig(),
  }) async {
    await waitForHostRouteSettled(context);
    if (!context.mounted) return null;
    final rect = await MorphSourceRect.resolveForMorph(sourceKey);
    if (!context.mounted) return null;
    if (rect == null) {
      _log('pushFrom: material fallback (source not measurable)');
      return _pushMaterial<T>(
        context: context,
        builder: builder,
        settings: settings,
      );
    }
    return pushFromRect<T>(
      context: context,
      sourceRect: rect,
      builder: builder,
      settings: settings,
      config: config,
    );
  }

  /// Pushes a named route with a morph transition from a pre-measured [sourceRect].
  ///
  /// Falls back to [Navigator.pushNamed] when the route is unknown, or to a
  /// standard [MaterialPageRoute] when [sourceRect] is `null`.
  static Future<T?> pushNamedFromRect<T>({
    required BuildContext context,
    required Rect? sourceRect,
    required String routeName,
    Object? arguments,
    MorphRouteConfig config = const MorphRouteConfig(),
  }) async {
    final settings = RouteSettings(name: routeName, arguments: arguments);
    final builder = AppRouter.pageBuilderFor(settings);
    if (builder == null) {
      return Navigator.of(context).pushNamed<T>(routeName, arguments: arguments);
    }
    if (sourceRect == null) {
      _log('pushNamedFromRect: material fallback (null rect)');
      return _pushMaterial<T>(
        context: context,
        builder: builder,
        settings: settings,
      );
    }
    // Rect is already measured — do not wait for host [ModalRoute.isCurrent].
    // Pause sheet / dialogs sit above gameplay; waiting would block ~60 frames.
    return pushFromRect<T>(
      context: context,
      sourceRect: sourceRect,
      builder: builder,
      settings: settings,
      config: config,
    );
  }

  /// Pushes [builder] with a morph transition from a pre-measured [sourceRect].
  ///
  /// Uses a short fade when [MorphMotion.prefersReducedMotion] is true.
  static Future<T?> pushFromRect<T>({
    required BuildContext context,
    required Rect sourceRect,
    required WidgetBuilder builder,
    RouteSettings? settings,
    MorphRouteConfig config = const MorphRouteConfig(),
  }) {
    final routeSettings = settings ?? const RouteSettings();
    if (MorphMotion.prefersReducedMotion(context)) {
      _log('pushFromRect: reduced-motion fade');
      return _pushReducedMotion<T>(
        context: context,
        builder: builder,
        settings: routeSettings,
      );
    }
    _log('pushFromRect: MorphPageRoute sourceRect=$sourceRect');
    StartupTimingLog.log(
      'Morph',
      'push.begin dur=${config.forwardDuration.inMilliseconds}ms',
    );
    final pushSerial = MorphRouteDebug.beginPush();
    MorphRouteDebug.logPushContext(
      pushSerial: pushSerial,
      context: context,
      transitionDuration: config.forwardDuration,
      reducedMotion: false,
    );
    return Navigator.of(context).push<T>(
      MorphPageRoute<T>(
        sourceRect: sourceRect,
        destinationBuilder: builder,
        settings: routeSettings,
        config: config,
        debugPushSerial: pushSerial,
      ),
    );
  }

  /// Waits until the [context] host route finished its entrance transition.
  ///
  /// Pushing a morph route while the host (e.g. shell after cold-start
  /// `pushReplacement`) is still animating causes the forward morph to be skipped.
  static Future<void> waitForHostRouteSettled(BuildContext context) async {
    const maxFrames = 60;
    final stopwatch = Stopwatch()..start();
    for (var frame = 0; frame < maxFrames; frame++) {
      if (!context.mounted) return;
      final route = ModalRoute.of(context);
      final animation = route?.animation;
      if (route == null || animation == null) {
        await SchedulerBinding.instance.endOfFrame;
        continue;
      }
      final settled =
          route.isCurrent &&
          !animation.isAnimating &&
          animation.status == AnimationStatus.completed;
      if (settled) {
        if (frame > 0) {
          _log('waitForHostRouteSettled: settled after $frame frames');
          StartupTimingLog.log(
            'Morph',
            'waitHost.done frames=$frame ms=${stopwatch.elapsedMilliseconds}',
          );
        }
        return;
      }
      await SchedulerBinding.instance.endOfFrame;
    }
    if (!context.mounted) return;
    final route = ModalRoute.of(context);
    _log('waitForHostRouteSettled: timed out after $maxFrames frames');
    StartupTimingLog.log(
      'Morph',
      'waitHost.timeout ms=${stopwatch.elapsedMilliseconds} '
      'isCurrent=${route?.isCurrent} anim=${route?.animation?.status}',
    );
  }

  static Future<T?> _pushReducedMotion<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    required RouteSettings settings,
  }) {
    final instant = MediaQuery.disableAnimationsOf(context);
    return Navigator.of(context).push<T>(
      MorphFadePageRoute<T>(
        destinationBuilder: builder,
        settings: settings,
        forwardDuration: instant ? Duration.zero : const Duration(milliseconds: 200),
        reverseDuration: instant ? Duration.zero : const Duration(milliseconds: 150),
      ),
    );
  }

  static Future<T?> _pushMaterial<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) {
    final routeSettings = settings ?? const RouteSettings();
    return Navigator.of(context).push<T>(
      MaterialPageRoute<T>(
        settings: routeSettings,
        builder: builder,
      ),
    );
  }

  static void _log(String message) {
    if (kDebugMode && MorphRouteDebug.verbose) {
      debugPrint('[MorphNav] $message');
    }
  }
}
