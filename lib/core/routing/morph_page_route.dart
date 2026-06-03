import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../debug/startup_timing_log.dart';
import 'morph_route_config.dart';
import 'morph_route_debug.dart';
import 'morph_shape.dart';

/// Max reverse-morph step per frame (guards against route tick jumps).
const Duration _kMorphMaxFrameDelta = Duration(milliseconds: 32);

/// A full-screen route that morphs from [sourceRect] into the destination page.
class MorphPageRoute<T> extends PageRoute<T> {
  MorphPageRoute({
    required this.sourceRect,
    required this.destinationBuilder,
    required super.settings,
    this.config = const MorphRouteConfig(),
    int debugPushSerial = 0,
  }) : _debugPushSerial = kDebugMode
            ? (debugPushSerial != 0
                ? debugPushSerial
                : MorphRouteDebug.beginPush())
            : 0;

  final Rect sourceRect;
  final WidgetBuilder destinationBuilder;
  final MorphRouteConfig config;
  final int _debugPushSerial;

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
  TickerFuture didPush() {
    final future = super.didPush();
    if (kDebugMode) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        final routeAnim = animation;
        if (routeAnim == null) return;
        MorphRouteDebug.logRouteAnimationSnapshot(
          pushSerial: _debugPushSerial,
          label: 'postPushFrame0',
          value: routeAnim.value,
          status: routeAnim.status,
        );
      });
    }
    return future;
  }

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
      if (kDebugMode) {
        debugPrint(
          '[MorphRoute] push#$_debugPushSerial buildTransitions: '
          'reduced motion (plain child)',
        );
      }
      return child;
    }
    return _MorphRouteTransition(
      pushSerial: _debugPushSerial,
      routeAnimation: animation,
      sourceRect: sourceRect,
      config: config,
      child: child,
    );
  }
}

class _MorphRouteTransition extends StatefulWidget {
  const _MorphRouteTransition({
    required this.pushSerial,
    required this.routeAnimation,
    required this.sourceRect,
    required this.config,
    required this.child,
  });

  final int pushSerial;
  final Animation<double> routeAnimation;
  final Rect sourceRect;
  final MorphRouteConfig config;
  final Widget child;

  @override
  State<_MorphRouteTransition> createState() => _MorphRouteTransitionState();
}

class _MorphRouteTransitionState extends State<_MorphRouteTransition> {
  final Stopwatch _forwardStopwatch = Stopwatch();
  Duration _elapsed = Duration.zero;
  Duration _lastFrameTimestamp = Duration.zero;
  bool _reversing = false;
  bool _frameScheduled = false;
  bool _loggedForwardEnd = false;
  int _buildCount = 0;

  @override
  void initState() {
    super.initState();
    _reversing = widget.routeAnimation.status == AnimationStatus.reverse;
    if (_reversing) {
      _elapsed = widget.config.forwardDuration;
      StartupTimingLog.log('Morph', 'reverse.start');
    } else {
      _forwardStopwatch.start();
      StartupTimingLog.log(
        'Morph',
        'forward.start dur=${widget.config.forwardDuration.inMilliseconds}ms',
      );
    }
    widget.routeAnimation.addStatusListener(_onRouteStatusChanged);
    _scheduleNextFrame();

    if (kDebugMode && widget.pushSerial > 0) {
      MorphRouteDebug.logRouteAnimationSnapshot(
        pushSerial: widget.pushSerial,
        label: 'morphInit routeAnim',
        value: widget.routeAnimation.value,
        status: widget.routeAnimation.status,
      );
    }
  }

  void _onRouteStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.reverse && !_reversing) {
      StartupTimingLog.log('Morph', 'reverse.start (route status)');
      setState(() => _reversing = true);
      _scheduleNextFrame();
    }
  }

  void _logForwardEndIfNeeded(Duration total) {
    if (_reversing || _loggedForwardEnd || !_isSettled(total)) {
      return;
    }
    _loggedForwardEnd = true;
    StartupTimingLog.log(
      'Morph',
      'forward.end wall=${_forwardStopwatch.elapsedMilliseconds}ms',
    );
  }

  void _scheduleNextFrame() {
    if (_frameScheduled || !mounted) return;
    _frameScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback(_onFrame);
  }

  void _onFrame(Duration timestamp) {
    _frameScheduled = false;
    if (!mounted) return;

    final total = _reversing
        ? widget.config.reverseDuration
        : widget.config.forwardDuration;

    if (!_reversing) {
      final wall = Duration(milliseconds: _forwardStopwatch.elapsedMilliseconds);
      setState(() {
        _elapsed = wall > total ? total : wall;
      });
      _logForwardEndIfNeeded(total);
      if (!_isSettled(total)) {
        _scheduleNextFrame();
      }
      return;
    }

    if (_lastFrameTimestamp == Duration.zero) {
      _lastFrameTimestamp = timestamp;
      if (!_isSettled(total)) {
        _scheduleNextFrame();
      }
      return;
    }

    var delta = timestamp - _lastFrameTimestamp;
    _lastFrameTimestamp = timestamp;
    final rawMs = delta.inMilliseconds;
    if (delta > _kMorphMaxFrameDelta) {
      MorphRouteDebug.logCappedFrameDelta(
        pushSerial: widget.pushSerial,
        rawMs: rawMs,
      );
      delta = _kMorphMaxFrameDelta;
    }

    setState(() {
      _elapsed -= delta;
      if (_elapsed < Duration.zero) {
        _elapsed = Duration.zero;
      }
    });

    MorphRouteDebug.logMorphProgress(
      pushSerial: widget.pushSerial,
      linearT: _linearProgress(total),
      routeValue: widget.routeAnimation.value,
      rawFrameDeltaMs: rawMs,
    );

    if (!_isSettled(total)) {
      _scheduleNextFrame();
    }
  }

  double _linearProgress(Duration total) {
    if (total == Duration.zero) return 1;
    return (_elapsed.inMicroseconds / total.inMicroseconds).clamp(0.0, 1.0);
  }

  bool _isSettled(Duration total) {
    return _reversing ? _elapsed <= Duration.zero : _elapsed >= total;
  }

  double get _positionProgress {
    final linear = _linearProgress(
      _reversing
          ? widget.config.reverseDuration
          : widget.config.forwardDuration,
    );
    return _reversing
        ? widget.config.reversePositionCurve.transform(linear)
        : widget.config.positionCurve.transform(linear);
  }

  @override
  void dispose() {
    widget.routeAnimation.removeStatusListener(_onRouteStatusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor =
        widget.config.surfaceColor ?? Theme.of(context).scaffoldBackgroundColor;

    _buildCount++;
    if (kDebugMode && widget.pushSerial > 0 && _buildCount <= 12) {
      MorphRouteDebug.logBuildTransitions(
        pushSerial: widget.pushSerial,
        rawValue: widget.routeAnimation.value,
        curvedValue: _positionProgress,
        status: _reversing
            ? AnimationStatus.reverse
            : AnimationStatus.forward,
        buildCount: _buildCount,
      );
    }

    final t = _positionProgress;
    final screenSize = MediaQuery.sizeOf(context);
    final morphRRect = MorphShape.interpolate(
      sourceRect: widget.sourceRect,
      targetSize: screenSize,
      positionProgress: t,
      sourceBorderRadius: widget.config.sourceBorderRadius,
      reversing: _reversing,
      forwardRadiusSoftenInterval: widget.config.forwardRadiusSoftenInterval,
      reverseRadiusGrowInterval: widget.config.reverseRadiusGrowInterval,
    );
    final outerRect = morphRRect.outerRect;
    final localRRect = MorphShape.toLocalSpace(morphRRect, outerRect);
    final contentT = _reversing
        ? widget.config.reverseContentHideInterval.transform(t)
        : widget.config.contentRevealInterval.transform(t);
    final opacity = contentT.clamp(0.0, 1.0);
    final scale = lerpDouble(widget.config.contentScaleBegin, 1.0, contentT)!;
    final revealSemantics = t >= widget.config.semanticRevealThreshold;
    final contentAlignment = MorphShape.contentAlignment(
      widget.sourceRect,
      screenSize,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fromRect(
          rect: outerRect,
          child: ClipPath(
            clipper: MorphShapeClipper(localRRect),
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: surfaceColor,
              elevation: lerpDouble(0, 2, t)!,
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  alignment: contentAlignment,
                  child: ExcludeSemantics(
                    excluding: !revealSemantics,
                    child: _MorphDestinationLayer(
                      screenSize: screenSize,
                      alignment: contentAlignment,
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Lays out [child] at full [screenSize] while the morph clip is still small.
///
/// Without this, tight constraints from [Positioned.fromRect] force destinations
/// such as gameplay screens to relayout in the card bounds and overflow.
class _MorphDestinationLayer extends StatelessWidget {
  const _MorphDestinationLayer({
    required this.screenSize,
    required this.alignment,
    required this.child,
  });

  final Size screenSize;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return OverflowBox(
      alignment: alignment,
      maxWidth: screenSize.width,
      minWidth: screenSize.width,
      maxHeight: screenSize.height,
      minHeight: screenSize.height,
      child: SizedBox(
        width: screenSize.width,
        height: screenSize.height,
        child: child,
      ),
    );
  }
}
