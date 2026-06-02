import 'package:flutter/material.dart';

/// A short fade route used when morph transitions should be avoided.
class MorphFadePageRoute<T> extends PageRoute<T> {
  MorphFadePageRoute({
    required this.destinationBuilder,
    required super.settings,
    this.forwardDuration = const Duration(milliseconds: 200),
    this.reverseDuration = const Duration(milliseconds: 150),
  });

  final WidgetBuilder destinationBuilder;
  final Duration forwardDuration;
  final Duration reverseDuration;

  @override
  bool get opaque => true;

  @override
  bool get maintainState => true;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => forwardDuration;

  @override
  Duration get reverseTransitionDuration => reverseDuration;

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
    if (forwardDuration == Duration.zero) {
      return child;
    }
    return FadeTransition(opacity: animation, child: child);
  }
}
