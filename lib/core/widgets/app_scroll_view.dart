import 'package:flutter/material.dart';

/// iOS-style bounce on all platforms for app scrollables.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics();
  }
}

/// Whether an ancestor [AppScrollView] is overscrolling or the user is scrolling.
///
/// Used to pause in-scroll loop animations (e.g. [MiniBoardShiftAnimation]) so
/// frame advances and [setState] do not fight scroll physics or [AnimatedSwitcher].
class ScrollOverscrollScope extends InheritedWidget {
  const ScrollOverscrollScope({
    super.key,
    required this.isOverscrolling,
    required this.pauseLinkedAnimations,
    required super.child,
  });

  final bool isOverscrolling;

  /// True while the user is dragging/flinging or the viewport is rubber-banding.
  final bool pauseLinkedAnimations;

  static ScrollOverscrollScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ScrollOverscrollScope>();
  }

  @override
  bool updateShouldNotify(ScrollOverscrollScope oldWidget) {
    return isOverscrolling != oldWidget.isOverscrolling ||
        pauseLinkedAnimations != oldWidget.pauseLinkedAnimations;
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
  ScrollController? _ownedController;
  VoidCallback? _scrollingListener;
  ScrollPosition? _listenedPosition;

  var _isOverscrolling = false;
  var _isUserScrolling = false;

  bool? _pendingOverscrolling;
  bool? _pendingUserScrolling;
  var _stateUpdateScheduled = false;

  ScrollController get _effectiveController =>
      widget.controller ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _ownedController = ScrollController();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _attachScrollingListener());
  }

  @override
  void didUpdateWidget(covariant AppScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detachScrollingListener();
      WidgetsBinding.instance.addPostFrameCallback((_) => _attachScrollingListener());
    }
  }

  @override
  void dispose() {
    _detachScrollingListener();
    _ownedController?.dispose();
    super.dispose();
  }

  void _attachScrollingListener() {
    if (!mounted || !_effectiveController.hasClients) return;

    final position = _effectiveController.position;
    if (_listenedPosition == position) return;

    _detachScrollingListener();
    _listenedPosition = position;
    _isUserScrolling = position.isScrollingNotifier.value;

    _scrollingListener = () {
      final scrolling = position.isScrollingNotifier.value;
      if (scrolling == _isUserScrolling) return;
      _pendingUserScrolling = scrolling;
      _scheduleStateUpdate();
    };
    position.isScrollingNotifier.addListener(_scrollingListener!);
  }

  void _detachScrollingListener() {
    if (_scrollingListener != null && _listenedPosition != null) {
      _listenedPosition!.isScrollingNotifier.removeListener(_scrollingListener!);
    }
    _scrollingListener = null;
    _listenedPosition = null;
  }

  void _scheduleStateUpdate() {
    if (_stateUpdateScheduled) return;
    _stateUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _stateUpdateScheduled = false;
      if (!mounted) return;

      var changed = false;
      if (_pendingOverscrolling != null &&
          _pendingOverscrolling != _isOverscrolling) {
        _isOverscrolling = _pendingOverscrolling!;
        changed = true;
      }
      _pendingOverscrolling = null;

      if (_pendingUserScrolling != null &&
          _pendingUserScrolling != _isUserScrolling) {
        _isUserScrolling = _pendingUserScrolling!;
        changed = true;
      }
      _pendingUserScrolling = null;

      if (changed) {
        setState(() {});
      }
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    final overscrolling = notification.metrics.outOfRange;
    final effectiveOverscrolling = _pendingOverscrolling ?? _isOverscrolling;
    if (overscrolling != effectiveOverscrolling) {
      _pendingOverscrolling = overscrolling;
      _scheduleStateUpdate();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: ScrollOverscrollScope(
        isOverscrolling: _isOverscrolling,
        pauseLinkedAnimations: _isOverscrolling || _isUserScrolling,
        child: SingleChildScrollView(
          controller: _effectiveController,
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
