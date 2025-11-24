/// Call Timer Utility
/// 
/// Provides a simple timer to track call duration.
/// 
/// Usage:
/// ```dart
/// final timer = CallTimer();
/// timer.start();
/// // Later...
/// final duration = timer.elapsed;
/// timer.stop();
/// ```

import 'dart:async';

class CallTimer {
  DateTime? _startTime;
  Timer? _periodicTimer;
  Duration _elapsed = Duration.zero;
  final void Function(Duration)? onTick;

  CallTimer({this.onTick});

  /// Start the timer
  void start() {
    if (_startTime != null) return; // Already started
    
    _startTime = DateTime.now();
    _elapsed = Duration.zero;
    
    _periodicTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsed = DateTime.now().difference(_startTime!);
      onTick?.call(_elapsed);
    });
  }

  /// Stop the timer
  void stop() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    if (_startTime != null) {
      _elapsed = DateTime.now().difference(_startTime!);
      _startTime = null;
    }
  }

  /// Reset the timer
  void reset() {
    stop();
    _elapsed = Duration.zero;
  }

  /// Get elapsed duration
  Duration get elapsed => _elapsed;

  /// Check if timer is running
  bool get isRunning => _periodicTimer != null && _periodicTimer!.isActive;

  /// Format duration as HH:MM:SS or MM:SS
  String get formatted {
    final hours = _elapsed.inHours;
    final minutes = _elapsed.inMinutes.remainder(60);
    final seconds = _elapsed.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
  }

  void dispose() {
    stop();
  }
}

