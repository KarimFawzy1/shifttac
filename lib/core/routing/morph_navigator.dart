import 'package:flutter/material.dart';

import 'app_router.dart';
import 'morph_page_route.dart';
import 'morph_route_config.dart';
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
  }) {
    final rect = MorphSourceRect.tryMeasure(sourceKey);
    if (rect == null) {
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
  }) {
    final settings = RouteSettings(name: routeName, arguments: arguments);
    final builder = AppRouter.pageBuilderFor(settings);
    if (builder == null) {
      return Navigator.of(context).pushNamed<T>(routeName, arguments: arguments);
    }
    if (sourceRect == null) {
      return _pushMaterial<T>(
        context: context,
        builder: builder,
        settings: settings,
      );
    }
    return pushFromRect<T>(
      context: context,
      sourceRect: sourceRect,
      builder: builder,
      settings: settings,
      config: config,
    );
  }

  /// Pushes [builder] with a morph transition from a pre-measured [sourceRect].
  static Future<T?> pushFromRect<T>({
    required BuildContext context,
    required Rect sourceRect,
    required WidgetBuilder builder,
    RouteSettings? settings,
    MorphRouteConfig config = const MorphRouteConfig(),
  }) {
    final routeSettings = settings ?? const RouteSettings();
    return Navigator.of(context).push<T>(
      MorphPageRoute<T>(
        sourceRect: sourceRect,
        destinationBuilder: builder,
        settings: routeSettings,
        config: config,
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
}
