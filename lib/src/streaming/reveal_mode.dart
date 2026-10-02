import 'package:flutter/animation.dart' show Curve, Cubic, Curves;

/// How revealed text arrives on screen (DESIGN.md section 4).
///
/// Passed as `revealMode:` to [StreamingText] and every
/// `StreamingTextMarkdown` constructor. Every mode still uses this package's
/// own reveal engine for pacing, lifecycle and the caret (see
/// PHASE-B1-PLAN.md's hybrid decision) — this only controls how each newly
/// revealed unit is painted, and (for [smoothFade]/[wordFade]) what unit
/// size the engine reveals in.
///
/// An explicit `revealMode: null` (the type is `RevealMode?`) opts OUT of
/// all of this and keeps the pre-2.0 behaviour driven entirely by the
/// legacy `wordByWord`/`fadeInEnabled`/`fadeInDuration`/`fadeInCurve`/
/// `chunkSize`/`typingSpeed` parameters.
enum RevealMode {
  /// The 2.0 default (DESIGN.md 4.1): word-unit reveal, a 180ms
  /// opacity-only fade on [smoothFadeCurve], for both plain text and
  /// markdown, on both `text` and `stream` input, including Arabic.
  smoothFade,

  /// The pre-2.0 `.claude()` preset, now available as a named mode: word
  /// units, a 220ms fade (`Curves.easeInOut`).
  wordFade,

  /// Character drip, no fade — the classic typewriter effect.
  typewriter,

  /// No animation: the source is revealed all at once.
  instant,
}

/// The shared "emphasized decelerate" enter curve used by
/// [RevealMode.smoothFade] (DESIGN.md 4.1).
const Curve smoothFadeCurve = Cubic(0.2, 0, 0, 1);

/// [RevealMode.smoothFade]'s fade duration (DESIGN.md 4.1: `streamFade`).
const Duration smoothFadeDuration = Duration(milliseconds: 180);

/// [RevealMode.wordFade]'s fade duration — the pre-2.0 `.claude()` preset's
/// tuned value.
const Duration wordFadeDuration = Duration(milliseconds: 220);

/// [RevealMode.wordFade]'s fade curve — the pre-2.0 `.claude()` preset's
/// tuned value.
const Curve wordFadeCurve = Curves.easeInOut;

/// How a [RevealMode]-driven reveal paces a `Stream<String>` (or static
/// `text`) source (DESIGN.md 4.3).
///
/// Construct via [StreamPacing.catchUp] or [StreamPacing.fixed]. When left
/// `null`, `Stream<String>` input defaults to [StreamPacing.catchUp] and
/// static `text` input defaults to [StreamPacing.fixed] using the widget's
/// own `typingSpeed`.
sealed class StreamPacing {
  const StreamPacing();

  /// Backlog-proportional catch-up pacing (the sibling chat UI's factor):
  /// smooths bursty token arrivals instead of draining them one fixed unit
  /// per tick. See [CatchUpPacer] in `lib/src/engine/reveal_pacer.dart` for
  /// the exact contract; the parameters here are forwarded to it.
  const factory StreamPacing.catchUp({
    Duration window,
    double k,
    double floorCharsPerSecond,
    Duration drainWithin,
  }) = _CatchUpPacing;

  /// Reveals exactly one unit every [typingSpeed] — the pre-2.0 behaviour.
  const factory StreamPacing.fixed(Duration typingSpeed) = _FixedPacing;
}

/// See [StreamPacing.catchUp].
final class _CatchUpPacing extends StreamPacing {
  const _CatchUpPacing({
    this.window = const Duration(milliseconds: 50),
    this.k = 0.16,
    this.floorCharsPerSecond = 30,
    this.drainWithin = const Duration(milliseconds: 400),
  });

  final Duration window;
  final double k;
  final double floorCharsPerSecond;
  final Duration drainWithin;
}

/// See [StreamPacing.fixed].
final class _FixedPacing extends StreamPacing {
  const _FixedPacing(this.typingSpeed);

  final Duration typingSpeed;
}

/// Internal accessors for the private [StreamPacing] subclasses, kept out
/// of the public API surface (callers only ever construct via the factory
/// constructors and never need to destructure one back apart).
extension StreamPacingInternal on StreamPacing {
  /// The catch-up tuning, or `null` when this is [StreamPacing.fixed].
  ({
    Duration window,
    double k,
    double floorCharsPerSecond,
    Duration drainWithin,
  })?
  get catchUpTuning {
    final self = this;
    if (self is _CatchUpPacing) {
      return (
        window: self.window,
        k: self.k,
        floorCharsPerSecond: self.floorCharsPerSecond,
        drainWithin: self.drainWithin,
      );
    }
    return null;
  }

  /// The fixed typing speed, or `null` when this is [StreamPacing.catchUp].
  Duration? get fixedTypingSpeed {
    final self = this;
    return self is _FixedPacing ? self.typingSpeed : null;
  }
}
