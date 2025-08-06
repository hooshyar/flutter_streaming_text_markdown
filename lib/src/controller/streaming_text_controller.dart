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

  /// Current state of the streaming animation
  StreamingTextState get state => _state;

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

  /// Sets the speed multiplier for the animation
  /// [multiplier] should be positive. 1.0 = normal speed, 2.0 = 2x speed, 0.5 = half speed
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

  /// Restarts the animation from the beginning
  void restart() {
    _progress = 0.0;
    _isCompleted = false;
    _isPaused = false;
    _updateState(StreamingTextState.animating);
    _notifyProgress();
  }

  /// Skips to the end of the animation immediately
  void skipToEnd() {
    _progress = 1.0;
    _isCompleted = true;
    _isPaused = false;
    _updateState(StreamingTextState.completed);
    _notifyProgress();
    _onCompleted?.call();
  }

  /// Stops the animation and resets to idle state
  void stop() {
    _progress = 0.0;
    _isCompleted = false;
    _isPaused = false;
    _updateState(StreamingTextState.idle);
    _notifyProgress();
  }

  /// Sets a callback for when the animation state changes
  void onStateChanged(void Function(StreamingTextState) callback) {
    _onStateChanged = callback;
  }

  /// Sets a callback for when the animation progress changes
  void onProgressChanged(void Function(double) callback) {
    _onProgressChanged = callback;
  }

  /// Sets a callback for when the animation completes
  void onCompleted(VoidCallback callback) {
    _onCompleted = callback;
  }

  /// Internal method to update the state (used by StreamingText widget)
  void updateState(StreamingTextState newState) {
    _updateState(newState);
  }

  /// Internal method to update progress (used by StreamingText widget)
  void updateProgress(double newProgress) {
    _progress = newProgress.clamp(0.0, 1.0);

    if (_progress >= 1.0 && !_isCompleted) {
      _isCompleted = true;
      _updateState(StreamingTextState.completed);
      _onCompleted?.call();
    }

    _notifyProgress();
  }

  /// Internal method to mark as completed
  void markCompleted() {
    _progress = 1.0;
    _isCompleted = true;
    _updateState(StreamingTextState.completed);
    _notifyProgress();
    _onCompleted?.call();
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
