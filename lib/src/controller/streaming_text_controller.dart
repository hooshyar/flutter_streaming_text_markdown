import 'package:flutter/foundation.dart';

/// Controller for programmatically controlling StreamingText animations.
///
/// This controller provides methods to pause, resume, restart, and skip
/// animations. Perfect for LLM applications where users need control
/// over text streaming behavior.
///
/// Example usage:
/// ```dart
/// final controller = StreamingTextController();
///
/// StreamingTextMarkdown(
///   text: llmResponse,
///   controller: controller,
/// )
///
/// // Pause the animation
/// controller.pause();
///
/// // Resume from where it was paused
/// controller.resume();
///
/// // Skip to the end immediately
/// controller.skipToEnd();
/// ```
class StreamingTextController extends ChangeNotifier {
  /// Creates a controller in the [StreamingTextState.idle] state.
  StreamingTextController();

  /// Internal state of the animation
  StreamingTextState _state = StreamingTextState.idle;

  /// Current progress of the animation (0.0 to 1.0)
  double _progress = 0.0;

  /// Whether the animation is currently paused
  bool _isPaused = false;

  /// Whether the animation has completed
  bool _isCompleted = false;

  /// Speed multiplier for the animation (1.0 = normal speed)
  double _speedMultiplier = 1.0;

  /// Callback for when animation state changes
  void Function(StreamingTextState)? _onStateChanged;

  /// Callback for when progress changes
  void Function(double)? _onProgressChanged;

  /// Callback for when animation completes
  VoidCallback? _onCompleted;

  /// The error that caused the controller to enter [StreamingTextState.error],
  /// if any. Cleared by [restart] and [stop].
  Object? _error;

  /// Current state of the streaming animation
  StreamingTextState get state => _state;

  /// The error that caused an error state, or `null` if there isn't one.
  Object? get error => _error;

  /// Current progress of the animation (0.0 to 1.0)
  double get progress => _progress;

  /// Whether the animation is currently paused
  bool get isPaused => _isPaused;

  /// Whether the animation has completed
  bool get isCompleted => _isCompleted;

  /// Whether the animation is currently running
  bool get isAnimating => _state == StreamingTextState.animating && !_isPaused;

  /// Speed multiplier for the animation
  double get speedMultiplier => _speedMultiplier;

  /// Sets the speed multiplier for the animation.
  ///
  /// [multiplier] should be positive. 1.0 = normal speed, 2.0 = 2x speed,
  /// 0.5 = half speed. The multiplier *divides* the configured typing
  /// speed (a larger multiplier reveals text faster).
  set speedMultiplier(double multiplier) {
    if (multiplier <= 0) {
      throw ArgumentError('Speed multiplier must be positive');
    }
    _speedMultiplier = multiplier;
    notifyListeners();
  }

  /// Pauses the animation
  void pause() {
    if (_state == StreamingTextState.animating && !_isPaused) {
      _isPaused = true;
      _updateState(StreamingTextState.paused);
    }
  }

  /// Resumes the animation from where it was paused
  void resume() {
    if (_isPaused) {
      _isPaused = false;
      _updateState(StreamingTextState.animating);
    }
  }

  /// Restarts the animation from the beginning.
  ///
  /// Re-arms the completion latch so the next completion of this new
  /// revealing→complete cycle fires [onCompleted] again.
  void restart() {
    _progress = 0.0;
    _isCompleted = false;
    _isPaused = false;
    _error = null;
    _updateState(StreamingTextState.animating);
    _notifyProgress();
  }

  /// Skips to the end of the animation immediately.
  void skipToEnd() {
    _completeOnce();
  }

  /// Stops the animation and resets to idle state.
  ///
  /// Re-arms the completion latch, same as [restart].
  void stop() {
    _progress = 0.0;
    _isCompleted = false;
    _isPaused = false;
    _error = null;
    _updateState(StreamingTextState.idle);
    _notifyProgress();
  }

  /// Sets a callback for when the animation state changes.
  ///
  /// Replaces any previously set callback; there is only ever one active
  /// listener registered this way.
  void onStateChanged(void Function(StreamingTextState) callback) {
    _onStateChanged = callback;
  }

  /// Sets a callback for when the animation progress changes.
  ///
  /// Replaces any previously set callback; there is only ever one active
  /// listener registered this way.
  void onProgressChanged(void Function(double) callback) {
    _onProgressChanged = callback;
  }

  /// Sets a callback for when the animation completes.
  ///
  /// Replaces any previously set callback; there is only ever one active
  /// listener registered this way. Fires at most once per
  /// revealing→complete cycle — see [_completeOnce].
  void onCompleted(VoidCallback callback) {
    _onCompleted = callback;
  }

  /// Internal method to update the state.
  ///
  /// For use by the `StreamingText` widget only; not part of the public
  /// programmatic control surface ([pause]/[resume]/[restart]/[stop]/
  /// [skipToEnd]).
  void updateState(StreamingTextState newState) {
    _updateState(newState);
  }

  /// Internal method to update progress.
  ///
  /// For use by the `StreamingText` widget only. Reaching 1.0 routes
  /// through [_completeOnce] so [onCompleted] fires at most once per cycle
  /// (W25).
  void updateProgress(double newProgress) {
    final clamped = newProgress.clamp(0.0, 1.0);
    if (clamped >= 1.0) {
      _completeOnce();
      return;
    }
    _progress = clamped;
    _notifyProgress();
  }

  /// Internal method to mark as completed.
  ///
  /// For use by the `StreamingText` widget only. Routes through
  /// [_completeOnce] so [onCompleted] fires at most once per cycle (W25).
  void markCompleted() {
    _completeOnce();
  }

  /// Marks an error state.
  ///
  /// Stops treating the controller as animating/paused and exposes [error].
  /// Does not clear [progress] or otherwise touch the completion latch —
  /// [restart] or [stop] are what re-arm the controller.
  void markError(Object error, [StackTrace? stackTrace]) {
    _error = error;
    _isPaused = false;
    _updateState(StreamingTextState.error);
    notifyListeners();
  }

  /// Completes the animation, firing [onCompleted] at most once per
  /// revealing→complete cycle.
  ///
  /// [markCompleted], [updateProgress] (once it reaches 1.0) and
  /// [skipToEnd] all route through here, so calling any combination of
  /// them for the same cycle notifies listeners of the completed state
  /// every time but only invokes [onCompleted] once. [restart] and [stop]
  /// are the only ways to re-arm the latch for a new cycle (W25).
  void _completeOnce() {
    _progress = 1.0;
    _isPaused = false;
    final alreadyCompleted = _isCompleted;
    _isCompleted = true;
    _updateState(StreamingTextState.completed);
    _notifyProgress();
    if (!alreadyCompleted) {
      _onCompleted?.call();
    }
  }

  void _updateState(StreamingTextState newState) {
    if (_state != newState) {
      _state = newState;
      _onStateChanged?.call(newState);
      notifyListeners();
    }
  }

  void _notifyProgress() {
    _onProgressChanged?.call(_progress);
    notifyListeners();
  }

  @override
  void dispose() {
    _onStateChanged = null;
    _onProgressChanged = null;
    _onCompleted = null;
    super.dispose();
  }
}

/// Represents the current state of a streaming text animation
enum StreamingTextState {
  /// Animation is not started or has been stopped
  idle,

  /// Animation is currently running
  animating,

  /// Animation is paused
  paused,

  /// Animation has completed
  completed,

  /// An error occurred during animation
  error,
}

/// Extension methods for StreamingTextState
extension StreamingTextStateExtension on StreamingTextState {
  /// Whether the animation is in a running state
  bool get isActive => this == StreamingTextState.animating;

  /// Whether the animation is finished
  bool get isFinished =>
      this == StreamingTextState.completed || this == StreamingTextState.error;

  /// Human-readable description of the state
  String get description {
    switch (this) {
      case StreamingTextState.idle:
        return 'Idle';
      case StreamingTextState.animating:
        return 'Animating';
      case StreamingTextState.paused:
        return 'Paused';
      case StreamingTextState.completed:
        return 'Completed';
      case StreamingTextState.error:
        return 'Error';
    }
  }
}
