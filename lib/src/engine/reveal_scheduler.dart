import 'dart:async';

import 'reveal_engine.dart';
import 'reveal_pacer.dart';

/// Drives a [RevealEngine] forward on exactly one `Timer.periodic`.
///
/// The scheduler idles (cancels its timer) whenever there is nothing left
/// to reveal and the engine's input is still open, instead of polling -
/// and wakes automatically the moment the engine's source grows (via
/// [RevealEngine.onSourceGrew]), or when [wake] is called explicitly.
class RevealScheduler {
  /// Wraps [engine], ticking it every [interval] using [pacer].
  RevealScheduler({
    required RevealEngine engine,
    Duration interval = const Duration(milliseconds: 30),
    this.pacer = const FixedPacer(),
  }) : _engine = engine,
       _interval = interval {
    _engine.onSourceGrew = wake;
  }

  final RevealEngine _engine;
  Duration _interval;

  /// The pacer used to compute how many units to reveal per tick.
  RevealPacer pacer;
  Timer? _timer;
  bool _paused = false;
  bool _disposed = false;

  /// The current tick interval. Assigning applies in place: an active
  /// timer is rescheduled at the new interval without losing the engine's
  /// cursor position. A no-op when [value] equals the current interval —
  /// otherwise a caller that re-syncs config on every notification (e.g. a
  /// [StreamingTextController] progress update, which fires on every tick)
  /// would cancel-and-recreate the `Timer.periodic` before it ever gets a
  /// chance to fire, permanently starving the reveal.
  Duration get interval => _interval;
  set interval(Duration value) {
    if (value == _interval) return;
    _interval = value;
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
      _ensureTimer();
    }
  }

  /// Whether a `Timer.periodic` is currently active (not paused, not
  /// idle, not disposed).
  bool get isRunning => _timer != null;

  /// Whether [pause] has been called without a matching [resume]/[start].
  bool get isPaused => _paused;

  /// Whether [dispose] has been called.
  bool get isDisposed => _disposed;

  /// Starts ticking (or stays idle if there is nothing to reveal yet and
  /// input is still open).
  void start() {
    if (_disposed) return;
    _paused = false;
    _ensureTimer();
  }

  /// Cancels the timer without losing position; [resume] picks up where
  /// it left off.
  void pause() {
    if (_disposed) return;
    _paused = true;
    _timer?.cancel();
    _timer = null;
  }

  /// Resumes ticking after [pause], from the same cursor position.
  void resume() {
    if (_disposed) return;
    _paused = false;
    _ensureTimer();
  }

  /// Cancels the timer. Unlike [pause], a subsequent [start] is expected
  /// (callers typically pair this with [RevealEngine.reset]).
  void stop() {
    if (_disposed) return;
    _paused = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Permanently stops the scheduler; it may not be started again.
  void dispose() {
    _disposed = true;
    _paused = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Wakes an idle scheduler after the engine's source has grown. Safe to
  /// call at any time (a no-op when paused, disposed, or already
  /// running/complete).
  void wake() {
    if (_paused || _disposed) return;
    _ensureTimer();
  }

  int get _backlog => _engine.source.length - _engine.cursor;

  void _ensureTimer() {
    if (_paused || _disposed) return;
    if (_timer != null) return;
    if (_backlog <= 0 && !_engine.inputClosed) {
      // Idle: nothing to reveal, and more might still come.
      return;
    }
    if (_backlog <= 0) return; // fully drained and closed: stay idle
    _timer = Timer.periodic(_interval, (_) => _tick());
  }

  void _tick() {
    if (_backlog <= 0) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    final units = pacer.unitsThisTick(_backlog);
    var progressed = false;
    for (var i = 0; i < units; i++) {
      if (_engine.step()) {
        progressed = true;
      } else {
        break;
      }
    }
    // Idle once nothing is left to reveal, OR once a tick makes no
    // progress at all - e.g. all that remains is a word/span/grapheme a
    // policy is withholding until more input arrives or the source closes.
    // [RevealEngine.onSourceGrew] (wired to [wake]) restarts the timer the
    // moment that changes, so this never turns into a busy-wait.
    if (_backlog <= 0 || !progressed) {
      _timer?.cancel();
      _timer = null;
    }
  }
}
