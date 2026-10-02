/// The inputs a [RevealPacer] uses to decide how much to reveal on a
/// single scheduler tick.
class PaceContext {
  /// Creates a pacing context for one tick.
  const PaceContext({
    required this.backlog,
    required this.interval,
    required this.inputClosed,
    this.sinceClosed,
  });

  /// Source length minus cursor, in UTF-16 code units.
  final int backlog;

  /// The scheduler's current tick interval (the wall-clock gap between
  /// ticks the pacer's rates should be rescaled against).
  final Duration interval;

  /// Whether the engine's input has been closed (no more chunks coming).
  final bool inputClosed;

  /// How long ago the input closed, or `null` while it's still open (or
  /// this is the first tick after closing and no time has elapsed yet).
  final Duration? sinceClosed;
}

/// What a [RevealPacer] decided to reveal on one scheduler tick.
class PaceDecision {
  /// Creates a pacing decision.
  const PaceDecision({required this.units, this.minChars = 0});

  /// The minimum number of [RevealEngine.step] calls to make this tick.
  final int units;

  /// The minimum number of characters that should end up revealed this
  /// tick. The scheduler keeps stepping whole units (never splitting one)
  /// until this budget is met, so the char budget always snaps up to the
  /// nearest unit boundary (e.g. a whole word).
  final int minChars;
}

/// Decides how many units a [RevealScheduler] should reveal on a single
/// tick, given the current backlog (source length minus cursor, in UTF-16
/// code units).
abstract class RevealPacer {
  /// Const constructor for subclasses.
  const RevealPacer();

  /// The full pacing contract: compute a [PaceDecision] from [context].
  ///
  /// The default implementation delegates to [unitsThisTick] for backward
  /// compatibility with pacers that only implement the legacy, units-only
  /// contract.
  PaceDecision decide(PaceContext context) {
    return PaceDecision(units: unitsThisTick(context.backlog));
  }

  /// Legacy contract: number of [RevealEngine.step] calls to make this
  /// tick, given only the backlog. The default implementation delegates to
  /// [decide] so pacers that only implement the new contract still work
  /// through this accessor.
  ///
  /// Must be `>= 0`.
  int unitsThisTick(int backlogUnits) {
    return decide(
      PaceContext(
        backlog: backlogUnits,
        interval: Duration.zero,
        inputClosed: false,
      ),
    ).units;
  }
}

/// The only pacer that shipped in Phase A: always reveals exactly one unit
/// per tick, regardless of backlog.
class FixedPacer extends RevealPacer {
  /// Creates a fixed, one-unit-per-tick pacer.
  const FixedPacer();

  @override
  int unitsThisTick(int backlogUnits) => 1;
}

/// A backlog-proportional pacer: reveals a fraction of the backlog per
/// window, subject to a floor rate, and accelerates to fully drain the
/// backlog shortly after the engine's input closes.
///
/// - Per window: `max(1 char, ceil(backlog * k))`, where `k` is calibrated
///   for [window] and rescaled to whatever tick [PaceContext.interval] the
///   scheduler is actually using.
/// - Never reveals below [floorCharsPerSecond].
/// - Once [PaceContext.inputClosed] is `true`, ramps up so the entire
///   remaining backlog is gone within [drainWithin] plus one more
///   [window] of grace, no matter how large it is.
class CatchUpPacer extends RevealPacer {
  /// Creates a catch-up pacer.
  const CatchUpPacer({
    this.window = const Duration(milliseconds: 50),
    this.k = 0.16,
    this.floorCharsPerSecond = 30,
    this.drainWithin = const Duration(milliseconds: 400),
  });

  /// The window [k] was calibrated against.
  final Duration window;

  /// Fraction of the backlog revealed per [window] (rescaled to the
  /// scheduler's actual tick interval).
  final double k;

  /// The minimum sustained reveal rate while there is any backlog.
  final double floorCharsPerSecond;

  /// How long after input closes the whole backlog must be gone (plus one
  /// extra window of grace).
  final Duration drainWithin;

  @override
  PaceDecision decide(PaceContext context) {
    final backlog = context.backlog;
    if (backlog <= 0) return const PaceDecision(units: 0, minChars: 0);

    final windowMs = window.inMilliseconds <= 0 ? 1 : window.inMilliseconds;
    final intervalMs =
        context.interval.inMilliseconds > 0
            ? context.interval.inMilliseconds
            : windowMs;
    final scale = intervalMs / windowMs;
    final scaledK = k * scale;

    var minChars = (backlog * scaledK).ceil();
    if (minChars < 1) minChars = 1;

    final floorChars = (floorCharsPerSecond * intervalMs / 1000).ceil();
    if (minChars < floorChars) minChars = floorChars;

    if (context.inputClosed) {
      final sinceClosed = context.sinceClosed ?? Duration.zero;
      final deadline = drainWithin + window;
      final remaining = deadline - sinceClosed;
      if (remaining <= Duration.zero) {
        minChars = backlog;
      } else {
        final remainingMicros = remaining.inMicroseconds;
        var ticksLeft = (remainingMicros / (intervalMs * 1000)).ceil();
        if (ticksLeft < 1) ticksLeft = 1;
        final needed = (backlog / ticksLeft).ceil();
        if (needed > minChars) minChars = needed;
      }
    }

    if (minChars > backlog) minChars = backlog;
    return PaceDecision(units: 1, minChars: minChars);
  }
}
