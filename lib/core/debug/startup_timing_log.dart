import 'package:flutter/foundation.dart';

/// Debug timestamps for cold-start BGM / SFX / morph ordering.
///
/// Logs look like: `[Timing +1234ms 14:32:01.234] BGM startMusic resume`.
abstract final class StartupTimingLog {
  StartupTimingLog._();

  static final Stopwatch _sinceAppStart = Stopwatch();

  /// Call once from [main] before other startup work.
  static void markAppStart() {
    if (!kDebugMode) return;
    _sinceAppStart
      ..reset()
      ..start();
    log('App', 'main');
  }

  static void log(String category, String event) {
    if (!kDebugMode) return;
    final now = DateTime.now();
    final clock =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.'
        '${now.millisecond.toString().padLeft(3, '0')}';
    debugPrint(
      '[Timing +${_sinceAppStart.elapsedMilliseconds}ms $clock] '
      '$category $event',
    );
  }
}
