import 'package:characters/characters.dart';

import 'atomic_spans.dart';
import 'unit_policy.dart';

/// One grapheme-safe reveal step, kept for a fade effect. At most 32 are
/// kept by [RevealEngine] at a time.
class RevealRun {
  /// Creates a record of one reveal step from [start] to [end].
  const RevealRun(this.start, this.end, this.revealedAt);

  /// Start offset (UTF-16), inclusive.
  final int start;

  /// End offset (UTF-16), exclusive.
  final int end;

  /// When this run was revealed, per the engine's injected clock.
  final DateTime revealedAt;

  @override
  String toString() => 'RevealRun($start, $end, $revealedAt)';
}

/// A pure-Dart, grapheme-safe reveal cursor into a source string.
///
/// [RevealEngine] is the single source of truth for "how much of the text
/// has been revealed so far". It never mutates [source] and never rewrites
/// it: [revealed] is always exactly `source.substring(0, cursor)`, and
/// [cursor] only ever sits on a grapheme-cluster boundary. This makes it
/// impossible to reproduce the audit's W1 (word mode rewriting whitespace),
/// W2 (dropped spaces after completion), W4 (Arabic char mode mutating
/// text), W5/W6 (index-vs-grapheme resume drift) and W24 (a non-append
/// text change restarting the reveal from zero) bugs by construction: there
/// is no code path that can produce revealed text which is not a literal
/// prefix of the source.
///
/// No Flutter imports: this class (and the rest of `lib/src/engine/`) is
/// pure Dart, independently testable with `package:test` and
/// `package:fake_async`.
class RevealEngine {
  /// Creates a reveal engine over an initially-empty source.
  ///
  /// Call [setSource] (or [append] then [close]) to give it text.
  RevealEngine({
    this.policy = const CharPolicy(),
    this.atomicSpans,
    this.onComplete,
    DateTime Function() clock = DateTime.now,
  }) : _clock = clock;

  /// The reveal policy in effect (char/chunk/word/atomic). May be swapped
  /// in place; takes effect on the next [step].
  UnitPolicy policy;

  /// The LaTeX-span detector in effect, or `null` when atomic-span
  /// withholding is disabled (LaTeX off).
  AtomicSpanDetector? atomicSpans;

  final DateTime Function() _clock;

  /// Fired exactly once per revealing-to-complete transition (see
  /// [isComplete]). Re-armed only by [reset] or a non-prefix [setSource].
  void Function()? onComplete;

  /// Invoked whenever more progress might have become possible: [source]
  /// grew via [append]/[setSource], or [inputClosed] just flipped from
  /// `false` to `true` (which releases whatever a policy was withholding
  /// only because more input could still arrive - a trailing word, an
  /// unclosed span, the final grapheme). A [RevealScheduler] uses this to
  /// wake up from idle without polling.
  void Function()? onSourceGrew;

  String _source = '';
  int _cursor = 0;
  bool _inputClosed = false;
  bool _completedFired = false;

  String? _revealedCache;
  int _revealedCacheCursor = -1;

  final List<RevealRun> _runs = <RevealRun>[];
  static const int _maxRuns = 32;

  /// The full, unmodified source text. Append-only or replaced wholesale;
  /// [RevealEngine] never mutates it.
  String get source => _source;

  /// A UTF-16 offset into [source] that always sits on a grapheme
  /// boundary: `0 <= cursor <= source.length`.
  int get cursor => _cursor;

  /// Whether [close] (or a `closed: true` [setSource]/[append]) has been
  /// called for the current source.
  bool get inputClosed => _inputClosed;

  /// `true` exactly when the cursor has reached the end of a closed
  /// source. This is the single completion condition [onComplete] latches
  /// on.
  bool get isComplete => _cursor >= _source.length && _inputClosed;

  /// The last (up to) 32 reveal steps, for driving a fade effect.
  List<RevealRun> get runs => List.unmodifiable(_runs);

  /// `source.substring(0, cursor)` - always a prefix of [source]. Cached
  /// per cursor position.
  String get revealed {
    if (_revealedCacheCursor != _cursor || _revealedCache == null) {
      _revealedCache = _source.substring(0, _cursor);
      _revealedCacheCursor = _cursor;
    }
    return _revealedCache!;
  }

  /// `cursor / source.length`, clamped strictly below `1.0` until
  /// [isComplete] is `true` (so UI code can tell "fully typed but the
  /// stream might still add more" apart from "done").
  ///
  /// Monotonic non-decreasing (until [reset] or a non-prefix [setSource]
  /// re-arms it): a streamed [append] grows the denominator instantly,
  /// which would otherwise make progress visibly *drop* the moment a new
  /// chunk arrives, before the cursor has had a chance to catch up. This
  /// latches the highest value seen so far instead.
  double get progress {
    if (isComplete) {
      _maxProgress = 1.0;
      return 1.0;
    }
    if (_source.isNotEmpty) {
      final raw = _cursor / _source.length;
      final clamped = raw < 1.0 ? raw : 0.999999;
      if (clamped > _maxProgress) _maxProgress = clamped;
    }
    return _maxProgress;
  }

  double _maxProgress = 0.0;

  /// Appends [chunk] to [source]. A pure prefix growth: the cursor and the
  /// completion latch are left exactly as they are (this is what keeps
  /// append-after-complete from dropping anything - W2).
  void append(String chunk) {
    if (chunk.isEmpty) return;
    setSource(_source + chunk, closed: _inputClosed);
  }

  /// Replaces [source] wholesale.
  ///
  /// If [s] starts with the already-[revealed] text, the cursor is left
  /// untouched (this covers plain growth, including growth that also
  /// rewrites not-yet-revealed text - the visible prefix never moves).
  /// Otherwise the cursor is moved back to the grapheme floor of the
  /// longest common prefix of the old [revealed] text and [s] (W24), and
  /// the completion latch is re-armed so a later completion can fire
  /// again.
  void setSource(String s, {bool closed = false}) {
    final oldLen = _source.length;
    final oldRevealed = revealed;
    final wasOpen = !_inputClosed;

    if (s == _source) {
      _inputClosed = _inputClosed || closed;
      if (wasOpen && _inputClosed) {
        // Closing releases anything a policy was withholding only because
        // more input could still arrive.
        onSourceGrew?.call();
      }
      _maybeComplete();
      return;
    }

    if (s.startsWith(oldRevealed)) {
      _source = s;
    } else {
      final commonLen = _commonPrefixLength(oldRevealed, s);
      final floor = _graphemeFloor(s, commonLen);
      _source = s;
      _cursor = floor;
      _completedFired = false;
      _maxProgress = s.isEmpty ? 0.0 : floor / s.length;
    }

    _inputClosed = closed;
    _invalidateCache();
    if (_source.length > oldLen || (wasOpen && _inputClosed)) {
      onSourceGrew?.call();
    }
    _maybeComplete();
  }

  /// Marks input as closed without changing [source]. Equivalent to
  /// `setSource(source, closed: true)`.
  void close() => setSource(_source, closed: true);

  /// Advances the cursor by (at most) one unit, per [policy], clamped so
  /// it never reveals into an open input's unterminated tail or strictly
  /// inside an atomic span. Returns `true` if the cursor moved.
  bool step() {
    if (_cursor >= _source.length) {
      _maybeComplete();
      return false;
    }
    var candidate = policy.nextBoundary(
      _source,
      _cursor,
      inputClosed: _inputClosed,
    );
    if (!_inputClosed) {
      final safe = _lastSafeBoundaryWhileOpen();
      if (candidate > safe) candidate = safe;
    }
    candidate = _clampForAtomicSpans(candidate);
    if (candidate <= _cursor) {
      return false;
    }
    _moveCursorTo(candidate);
    _maybeComplete();
    return true;
  }

  /// Moves the cursor straight to the end of [source], bypassing the
  /// policy and any open-input withholding (used for tap-to-complete and
  /// `animationsEnabled: false`). Still respects [isComplete]'s
  /// `inputClosed` requirement: this alone does not fire [onComplete]
  /// unless input is already closed.
  void revealAll() {
    if (_cursor < _source.length) {
      _moveCursorTo(_source.length);
    }
    _maybeComplete();
  }

  /// Restarts the reveal of the *current* source from the beginning,
  /// re-arming the completion latch. Does not touch [source] or
  /// [inputClosed].
  void reset() {
    _cursor = 0;
    _completedFired = false;
    _maxProgress = 0.0;
    _runs.clear();
    _invalidateCache();
  }

  static const int _zwj = 0x200D;
  static const int _regionalIndicatorStart = 0x1F1E6;
  static const int _regionalIndicatorEnd = 0x1F1FF;

  int _lastSafeBoundaryWhileOpen() {
    if (_source.isEmpty) return 0;
    final range = CharacterRange.at(_source, _source.length);
    if (!range.moveBack()) return 0;
    var boundary = range.stringBeforeLength;

    // Two Unicode grapheme rules let a chunk boundary that `characters`
    // currently reports as safe get retroactively swallowed once more
    // input arrives, because the segmenter can only see what's arrived so
    // far:
    var changed = true;
    while (changed) {
      changed = false;

      // GB11: a ZWJ always attaches BACKWARD to whatever preceded it (which
      // is how a boundary can land right after one - e.g. the next chunk
      // starts with an unresolved/lone surrogate half `characters` can't
      // yet classify as a pictographic) - but it can also pull the NEXT
      // pictographic that arrives back into that same cluster, undoing a
      // boundary we'd otherwise have already revealed.
      if (boundary > 0 && _source.codeUnitAt(boundary - 1) == _zwj) {
        final prev = CharacterRange.at(_source, boundary);
        if (!prev.moveBack()) return 0;
        boundary = prev.stringBeforeLength;
        changed = true;
        continue;
      }

      // GB12/GB13: regional indicators pair up two at a time. A lone,
      // not-yet-paired flag letter at the tail (the last cluster is
      // exactly one regional indicator) can still pair with the next one
      // that arrives to form a single two-letter flag, which would swallow
      // this boundary too.
      if (boundary >= 2 && _isRegionalIndicator(_source, boundary - 2)) {
        final clusterStartRange = CharacterRange.at(_source, boundary);
        if (!clusterStartRange.moveBack()) return 0;
        final clusterStart = clusterStartRange.stringBeforeLength;
        if (boundary - clusterStart == 2) {
          boundary = clusterStart;
          changed = true;
        }
      }
    }
    return boundary;
  }

  /// Whether the surrogate pair starting at UTF-16 offset [index] encodes a
  /// Unicode regional indicator symbol (the "flag letters" used in pairs to
  /// form country flag emoji, U+1F1E6-U+1F1FF).
  static bool _isRegionalIndicator(String s, int index) {
    if (index < 0 || index + 1 >= s.length) return false;
    final hi = s.codeUnitAt(index);
    final lo = s.codeUnitAt(index + 1);
    if (hi < 0xD800 || hi > 0xDBFF || lo < 0xDC00 || lo > 0xDFFF) return false;
    final codePoint = 0x10000 + ((hi - 0xD800) << 10) + (lo - 0xDC00);
    return codePoint >= _regionalIndicatorStart &&
        codePoint <= _regionalIndicatorEnd;
  }

  int _clampForAtomicSpans(int candidate) {
    final detector = atomicSpans;
    if (detector == null) return candidate;
    for (final span in detector.spans(_source)) {
      // An unclosed span (no matching delimiter found yet) only needs
      // protecting while more input might still arrive to close it. Once
      // input is closed, nothing will ever close it, so treating it as
      // atomic forever would make the cursor stick at `span.start` and the
      // engine would never reach `isComplete` (a stray/unbalanced `$` in a
      // finished document must not stall the reveal).
      if (!span.closed && _inputClosed) continue;

      if (_cursor >= span.start && _cursor < span.end) {
        // The cursor is already parked at (or, per the invariant, exactly
        // on) the span's start boundary: a span is revealed as a single
        // atomic unit, so the only legal next boundary is straight past
        // it - never candidate-by-candidate through the middle. Without
        // this, any candidate that lands inside the span keeps getting
        // clamped back to the cursor's own current position (`span.start`)
        // forever, and `step()` never makes progress again.
        //
        // A still-open, not-yet-closed span can't be jumped yet - the next
        // chunk might still change where it ends - so it holds the cursor
        // in place until either it closes or input closes (handled above).
        return span.closed ? span.end : _cursor;
      }

      if (span.containsStrictly(candidate)) {
        return span.start;
      }
    }
    return candidate;
  }

  void _moveCursorTo(int newCursor) {
    if (newCursor == _cursor) return;
    _runs.add(RevealRun(_cursor, newCursor, _clock()));
    if (_runs.length > _maxRuns) {
      _runs.removeAt(0);
    }
    _cursor = newCursor;
    _invalidateCache();
  }

  void _maybeComplete() {
    if (isComplete && !_completedFired) {
      _completedFired = true;
      onComplete?.call();
    }
  }

  void _invalidateCache() {
    _revealedCache = null;
    _revealedCacheCursor = -1;
  }
}

int _commonPrefixLength(String a, String b) {
  final maxLen = a.length < b.length ? a.length : b.length;
  var i = 0;
  while (i < maxLen && a.codeUnitAt(i) == b.codeUnitAt(i)) {
    i++;
  }
  return i;
}

/// Snaps [index] down to the nearest grapheme boundary at or before it in
/// [source] (the "grapheme floor").
int _graphemeFloor(String source, int index) {
  if (index <= 0) return 0;
  if (index >= source.length) return source.length;
  final range = CharacterRange.at(source, index);
  return range.stringBeforeLength;
}
