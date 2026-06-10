import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Throttles Commons avatar downloads to avoid Wikimedia HTTP 429 bursts.
class PlayerAvatarImageQueue {
  PlayerAvatarImageQueue._();

  static final PlayerAvatarImageQueue instance = PlayerAvatarImageQueue._();

  /// Small parallel batch — faster than serial, safer than unbounded bursts.
  @visibleForTesting
  static const maxConcurrent = 5;

  /// Stagger each new slot start so five downloads do not hit Commons in one tick.
  static const _gapBetweenStarts = Duration(milliseconds: 200);
  static const _rateLimitedRetryDelays = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
  ];

  final List<_LoadTask> _queue = [];
  final Map<String, Future<void>> _inFlight = {};

  int _activeCount = 0;
  bool _draining = false;
  DateTime _lastStartAt = DateTime.fromMillisecondsSinceEpoch(0);

  String cacheKey(String url, int cacheSize) => '${url.trim()}|$cacheSize';

  Future<void> ensureCached({
    required ImageProvider<Object> provider,
    required String dedupeKey,
    required ImageConfiguration configuration,
  }) {
    if (PaintingBinding.instance.imageCache.containsKey(provider)) {
      return Future<void>.value();
    }

    final inflight = _inFlight[dedupeKey];
    if (inflight != null) {
      return inflight;
    }

    final completer = Completer<void>();
    final future = completer.future;
    _inFlight[dedupeKey] = future;

    _queue.add(
      _LoadTask(
        provider: provider,
        configuration: configuration,
        completer: completer,
        attempt: 0,
      ),
    );
    _scheduleDrain();

    return future.whenComplete(() {
      _inFlight.remove(dedupeKey);
    });
  }

  void _scheduleDrain() {
    if (_draining) {
      return;
    }
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_draining) {
      return;
    }
    _draining = true;

    while (_queue.isNotEmpty && _activeCount < maxConcurrent) {
      final elapsed = DateTime.now().difference(_lastStartAt);
      if (elapsed < _gapBetweenStarts) {
        await Future.delayed(_gapBetweenStarts - elapsed);
      }

      final task = _queue.removeAt(0);
      _lastStartAt = DateTime.now();
      _activeCount++;
      unawaited(_runTask(task));
    }

    _draining = false;

    if (_queue.isNotEmpty && _activeCount < maxConcurrent) {
      _scheduleDrain();
    }
  }

  Future<void> _runTask(_LoadTask task) async {
    try {
      await _resolveProvider(task.provider, task.configuration);
      if (!task.completer.isCompleted) {
        task.completer.complete();
      }
    } catch (error, stackTrace) {
      if (_isRateLimited(error) &&
          task.attempt < _rateLimitedRetryDelays.length) {
        await Future.delayed(_rateLimitedRetryDelays[task.attempt]);
        _queue.insert(0, task.copyWithAttempt(task.attempt + 1));
      } else if (!task.completer.isCompleted) {
        task.completer.completeError(error, stackTrace);
      }
    } finally {
      _activeCount--;
      _scheduleDrain();
    }
  }

  Future<void> _resolveProvider(
    ImageProvider<Object> provider,
    ImageConfiguration configuration,
  ) {
    final stream = provider.resolve(configuration);
    final completer = Completer<void>();

    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (image, synchronousCall) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      onError: (error, stackTrace) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
    );

    stream.addListener(listener);
    return completer.future;
  }

  bool _isRateLimited(Object error) {
    return error is NetworkImageLoadException && error.statusCode == 429;
  }

  @visibleForTesting
  void resetForTest() {
    _queue.clear();
    _inFlight.clear();
    _activeCount = 0;
    _draining = false;
    _lastStartAt = DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class _LoadTask {
  const _LoadTask({
    required this.provider,
    required this.configuration,
    required this.completer,
    required this.attempt,
  });

  final ImageProvider<Object> provider;
  final ImageConfiguration configuration;
  final Completer<void> completer;
  final int attempt;

  _LoadTask copyWithAttempt(int nextAttempt) {
    return _LoadTask(
      provider: provider,
      configuration: configuration,
      completer: completer,
      attempt: nextAttempt,
    );
  }
}
