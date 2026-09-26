/// A `[start, end)` UTF-16 range in the source that a [RevealEngine] must
/// never reveal a strict prefix of: the cursor may land at [start] or
/// [end], never strictly between them.
class AtomicSpan {
  /// Creates an atomic span covering `[start, end)`.
  const AtomicSpan(this.start, this.end, {required this.closed});

  /// Start offset, inclusive.
  final int start;

  /// End offset, exclusive.
  final int end;

  /// Whether a matching closing delimiter was found in the source. When
  /// `false`, [end] is simply `source.length` (the span runs off the end
  /// of what's available so far).
  final bool closed;

  /// Whether [index] falls strictly inside this span (not at a boundary).
  bool containsStrictly(int index) => index > start && index < end;

  @override
  String toString() => 'AtomicSpan($start, $end, closed: $closed)';
}

/// Finds LaTeX spans (`$...$`, `$$...$$`, `\(...\)`, `\[...\]`) in a
/// markdown source string, skipping anything inside fenced (``` ```) or
/// inline (`` ` ``) code, so shell `$VARS` in a code fence are never
/// mistaken for LaTeX (W11).
///
/// This is a lightweight, single-pass scanner - good enough to keep a
/// [RevealEngine] cursor out of the middle of a formula; it is not a full
/// markdown/LaTeX parser.
class AtomicSpanDetector {
  /// Creates a detector. Stateless and cheap to construct.
  const AtomicSpanDetector();

  static const _fence = '```';
  static const _dollarDollar = r'$$';
  static const _dollar = r'$';
  static const _backtick = '`';
  static const _parenOpen = r'\(';
  static const _parenClose = r'\)';
  static const _bracketOpen = r'\[';
  static const _bracketClose = r'\]';

  /// Returns every LaTeX span found in [source], outside of code.
  List<AtomicSpan> spans(String source) {
    final result = <AtomicSpan>[];
    final len = source.length;
    var i = 0;
    var inFence = false;
    var inInlineCode = false;

    while (i < len) {
      if (!inInlineCode && source.startsWith(_fence, i)) {
        inFence = !inFence;
        i += _fence.length;
        continue;
      }
      if (inFence) {
        i++;
        continue;
      }
      if (source.startsWith(_backtick, i)) {
        inInlineCode = !inInlineCode;
        i++;
        continue;
      }
      if (inInlineCode) {
        i++;
        continue;
      }

      if (source.startsWith(_dollarDollar, i)) {
        i = _consumeSpan(source, result, i, _dollarDollar, _dollarDollar);
        continue;
      }
      if (source.startsWith(_dollar, i)) {
        i = _consumeSpan(source, result, i, _dollar, _dollar);
        continue;
      }
      if (source.startsWith(_parenOpen, i)) {
        i = _consumeSpan(source, result, i, _parenOpen, _parenClose);
        continue;
      }
      if (source.startsWith(_bracketOpen, i)) {
        i = _consumeSpan(source, result, i, _bracketOpen, _bracketClose);
        continue;
      }
      i++;
    }
    return result;
  }

  int _consumeSpan(
    String source,
    List<AtomicSpan> result,
    int start,
    String open,
    String close,
  ) {
    final searchFrom = start + open.length;
    final closeAt = source.indexOf(close, searchFrom);
    final end = closeAt == -1 ? source.length : closeAt + close.length;
    result.add(AtomicSpan(start, end, closed: closeAt != -1));
    return end;
  }
}
