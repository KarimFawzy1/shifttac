import 'package:flutter/material.dart';

/// iOS-style bounce on all platforms for app scrollables.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics();
  }
}

/// Whether an ancestor [AppScrollView] is currently overscrolling (rubber-band).
///
/// Used to pause in-scroll loop animations (e.g. [MiniBoardShiftAnimation]) so
/// [setState] does not fight the bounce physics.
class ScrollOverscrollScope extends InheritedWidget {
  const ScrollOverscrollScope({
    super.key,
    required this.isOverscrolling,
    required super.child,
  });

  final bool isOverscrolling;

  static ScrollOverscrollScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ScrollOverscrollScope>();
  }

  @override
  bool updateShouldNotify(ScrollOverscrollScope oldWidget) {
    return isOverscrolling != oldWidget.isOverscrolling;
  }
}

/// Vertical scroll with bounce physics and overscroll signaling for descendants.
class AppScrollView extends StatefulWidget {
  const AppScrollView({
    super.key,
    required this.child,
    this.controller,
    this.padding,
    this.primary,
    this.clipBehavior = Clip.hardEdge,
  });

  final Widget child;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final bool? primary;
  final Clip clipBehavior;

  @override
  State<AppScrollView> createState() => _AppScrollViewState();
}

class _AppScrollViewState extends State<AppScrollView> {
  var _isOverscrolling = false;

  bool _handleScrollNotification(ScrollNotification notification) {
    final overscrolling = notification.metrics.outOfRange;
    if (overscrolling != _isOverscrolling) {
      setState(() => _isOverscrolling = overscrolling);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: ScrollOverscrollScope(
        isOverscrolling: _isOverscrolling,
        child: SingleChildScrollView(
          controller: widget.controller,
          padding: widget.padding,
          primary: widget.primary,
          clipBehavior: widget.clipBehavior,
          physics: const BouncingScrollPhysics(),
          child: widget.child,
        ),
      ),
    );
  }
}
