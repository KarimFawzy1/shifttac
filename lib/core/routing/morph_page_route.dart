import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'morph_route_config.dart';

/// A full-screen route that morphs from [sourceRect] into the destination page.
class MorphPageRoute<T> extends PageRoute<T> {
  MorphPageRoute({
    required this.sourceRect,
    required this.destinationBuilder,
    required super.settings,
    this.config = const MorphRouteConfig(),
  });

  final Rect sourceRect;
  final WidgetBuilder destinationBuilder;
  final MorphRouteConfig config;

  @override
  bool get opaque => true;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => config.forwardDuration;

  @override
  Duration get reverseTransitionDuration => config.reverseDuration;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return destinationBuilder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return _MorphRouteTransition(
      animation: animation,
      sourceRect: sourceRect,
      config: config,
      child: child,
    );
  }
}

class _MorphRouteTransition extends StatelessWidget {
  const _MorphRouteTransition({
    required this.animation,
    required this.sourceRect,
    required this.config,
    required this.child,
  });

  final Animation<double> animation;
  final Rect sourceRect;
  final MorphRouteConfig config;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: config.positionCurve,
      reverseCurve: config.reversePositionCurve,
    );
    final surfaceColor =
        config.surfaceColor ?? Theme.of(context).scaffoldBackgroundColor;

    return AnimatedBuilder(
      animation: Listenable.merge([curved, animation]),
      builder: (context, child) {
        final t = curved.value;
        final screenSize = MediaQuery.sizeOf(context);
        final targetRect = Offset.zero & screenSize;
        final rect = Rect.lerp(sourceRect, targetRect, t)!;
        final radius = lerpDouble(config.sourceBorderRadius, 0, t)!;
        final isReversing = animation.status == AnimationStatus.reverse;
        final contentT = isReversing
            ? config.reverseContentHideInterval.transform(t)
            : config.contentRevealInterval.transform(t);
        final opacity = contentT.clamp(0.0, 1.0);
        final scale = lerpDouble(config.contentScaleBegin, 1.0, contentT)!;
        final revealSemantics = t >= config.semanticRevealThreshold;

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fromRect(
              rect: rect,
              child: Material(
                color: surfaceColor,
                elevation: lerpDouble(0, 2, t)!,
                borderRadius: BorderRadius.circular(radius),
                clipBehavior: Clip.antiAlias,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.center,
                      child: ExcludeSemantics(
                        excluding: !revealSemantics,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: child,
    );
  }
}
