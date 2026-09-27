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
///
/// A single `$` only ever opens/closes a math span when it looks like real
/// LaTeX rather than currency, using pandoc's own heuristic: an opening `$`
/// must be immediately followed by a non-space character, a closing `$`
/// must be immediately preceded by a non-space character and NOT followed
/// by a digit, and a `$` matching the currency grammar
/// `$N([kKmMbB]|bn|mn|tn)?((-|–|—)($N|N)([kKmMbB]|bn|mn|tn)?)?` - `N` is a
/// run of digits with `.`/`,` allowed between digits (`5.99`, `1,000`),
/// an optional magnitude suffix (`$10k`, `$5M`, `$2B`, `$5bn`, `$2.5tn`),
/// and an optional `-`/`–`/`—`-joined range (`$5-10`, `$5–10`, `$10-$20`,
/// `$5—$10`, `$10k-$20k`, `$20-30/month`) - followed by whitespace or
/// punctuation (including the markdown markers `*`, `_`, `~`) is
/// currency, never an opening delimiter.
/// Running out of input mid-match while the source is still streaming is
/// ambiguous, not currency; and `-` heading into real math (`$1-p$`,
/// `$2k-1$`, `$1-\alpha$`) is not a range either, so those fall through to
/// the pandoc rules. Without this, `latexEnabled` on an open (still
/// streaming) source would treat a bare `$5` as an unclosed span and freeze
/// the reveal right before it, since more input could - as far as the
/// detector could tell - still arrive to "close" it.
///
/// An unclosed span (no matching delimiter found yet) is only withheld
/// within the current paragraph (up to the next blank line, `\n\n`, or the
/// end of the source if the paragraph hasn't finished yet): once a
/// paragraph has actually ended without a matching delimiter turning up
/// inside it, a stray `$`/`\(`/`\[` was never going to close there and must
/// not hold the cursor hostage waiting for one in some later paragraph.
/// A single `$` in a still-open paragraph is additionally capped: it holds
/// back at most 32 UTF-16 units or to the end of the current line,
/// whichever comes first, then reveals as a literal - a runaway unclosed
/// `$` would otherwise freeze the reveal for the whole rest of a long
/// streaming paragraph. `$$...$$`, `\(...\)` and `\[...\]` keep the plain
/// paragraph bound; the search for their closing delimiter is not capped.
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
  static const _paragraphBreak = '\n\n';

  /// How far (in UTF-16 units from the opening `$`) an unclosed
  /// single-`$` span may hold the reveal back while the paragraph is
  /// still open before the `$` is treated as literal text.
  static const _unclosedDollarBudget = 32;

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
        if (_isEscaped(source, i)) {
          // `\$$` (or `\$` immediately before a second, unescaped `$`): the
          // escaping backslash makes this `$` literal, so it can't open a
          // `$$...$$` span either - leave it as plain text, one char at a
          // time, same as a lone escaped `$` below.
          i++;
          continue;
        }
        i = _consumeSpan(source, result, i, _dollarDollar, _dollarDollar);
        continue;
      }
      if (source.startsWith(_dollar, i)) {
        if (_dollarOpensMath(source, i)) {
          i = _consumeDollarSpan(source, result, i);
        } else {
          // Currency (or otherwise not a real opening delimiter): a plain
          // character, not the start of a span.
          i++;
        }
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

  /// Rewrites paired, non-code `$...$` / `$$...$$` spans found by [spans] to
  /// `gpt_markdown`'s native `\(...\)` / `\[...\]` LaTeX syntax, leaving
  /// currency-shaped `$`, fenced/inline code, and already-native `\(...\)`/
  /// `\[...\]` spans untouched.
  ///
  /// Used instead of forwarding `useDollarSignsForLatex` to `gpt_markdown`
  /// itself: that rewrite runs before `gpt_markdown` knows what is code,
  /// so `$VARS` inside a fenced shell block gets mangled into a LaTeX
  /// delimiter (W11). This scan already skips code and applies the
  /// currency heuristic above, so it is safe to run over the full, mixed
  /// markdown+code source.
  String rewriteDollarDelimiters(String source) {
    final dollarSpans =
        spans(source)
            .where(
              (s) =>
                  s.closed &&
                  (source.startsWith(_dollarDollar, s.start) ||
                      source.startsWith(_dollar, s.start)),
            )
            .toList();
    if (dollarSpans.isEmpty) return source;

    final buffer = StringBuffer();
    var cursor = 0;
    for (final span in dollarSpans) {
      buffer.write(source.substring(cursor, span.start));
      final isDouble = source.startsWith(_dollarDollar, span.start);
      final delimiterLength = isDouble ? 2 : 1;
      final inner = source.substring(
        span.start + delimiterLength,
        span.end - delimiterLength,
      );
      if (isDouble) {
        buffer
          ..write(_bracketOpen)
          ..write(inner)
          ..write(_bracketClose);
      } else {
        buffer
          ..write(_parenOpen)
          ..write(inner)
          ..write(_parenClose);
      }
      cursor = span.end;
    }
    buffer.write(source.substring(cursor));
    return buffer.toString();
  }

  /// Whether the `$`/`\(`/`\[` etc. delimiter character at [index] is
  /// escaped: preceded by an ODD run of backslashes. `\$` is a literal `$`
  /// (the backslash is consumed by markdown's own escaping, same as `\*` or
  /// `\_`); `\\$` is an escaped backslash followed by a live `$`, which is
  /// why the run length's parity - not merely "is the previous char a
  /// backslash" - is what decides it.
  static bool _isEscaped(String source, int index) {
    var count = 0;
    var j = index - 1;
    while (j >= 0 && source[j] == '\\') {
      count++;
      j--;
    }
    return count.isOdd;
  }

  /// Whether [c] is a single-char currency magnitude suffix (`$10k`,
  /// `$5M`, `$2B`): still currency, never the start of a LaTeX span.
  static bool _isMagnitudeSuffix(String c) =>
      c == 'k' || c == 'K' || c == 'm' || c == 'M' || c == 'b' || c == 'B';

  /// Whether [c] joins a currency range (`$5-10`, `$5–10`, `$5—$10`).
  static bool _isRangeJoiner(String c) => c == '-' || c == '–' || c == '—';

  /// Consumes an optional currency magnitude suffix at [i]: a single
  /// `kKmMbB` char or a two-char `bn`, `mn` or `tn` (`$5bn`, `$2.5tn`,
  /// `$300mn`). The two-char forms must be tried first - `b` and `m` are
  /// also valid single-char suffixes, so `$5bn` would otherwise stop at
  /// the `b` and see the `n` as a non-currency follower. Returns the
  /// index just past the suffix, or [i] itself when there is none.
  static int _consumeMagnitudeSuffix(String source, int i) {
    if (i + 1 < source.length) {
      final c = source[i];
      if ((c == 'b' || c == 'm' || c == 't') && source[i + 1] == 'n') {
        return i + 2;
      }
    }
    if (i < source.length && _isMagnitudeSuffix(source[i])) return i + 1;
    return i;
  }

  /// Whether a `$` at [index] can open a LaTeX span at all, per the
  /// pandoc-style currency rules on the class doc.
  bool _dollarOpensMath(String source, int index) {
    if (_isEscaped(source, index)) return false;
    final next = index + 1;
    if (next >= source.length) return false;
    final nextChar = source[next];
    if (_isSpace(nextChar)) return false;
    if (_isDigit(nextChar)) {
      // One currency grammar:
      // `$N([kKmMbB]|bn|mn|tn)?((-|–|—)($N|N)([kKmMbB]|bn|mn|tn)?)?`
      // followed by whitespace or punctuation is currency (`$5 `, `$2B,`,
      // `**$20**`, `_$5_`, `~~$5~~`, `$5bn`, `$5-10 per month`, `$5–10`,
      // `$5—$10`, `$10-$20`, `$20-30/month`). Running out of input
      // mid-match is ambiguous while still streaming. Anything else
      // (`$1-p$`, `$10x$`) is not a currency match at all and falls
      // through to the pandoc opening rule.
      final currencyEnd = _matchCurrencyEnd(source, next);
      if (currencyEnd == -1) return false;
      final after = source[currencyEnd];
      if (_isSpace(after) || _isPunctuation(after)) return false;
    }
    return true;
  }

  /// Matches the currency grammar at [i], where `source[i - 1]` is the
  /// `$` and `source[i]` is a digit:
  ///
  ///   `N ([kKmMbB]|bn|mn|tn)? (('-'|'–'|'—') ('$' N | N)
  ///   ([kKmMbB]|bn|mn|tn)?)?`
  ///
  /// Returns the index just past the whole match, or -1 when the input
  /// ends before the match can be resolved: a mid-match end while the
  /// source is still streaming is ambiguous rather than currency (a bare
  /// trailing `$5`, `$10-`, or `$10-$` could still grow into either).
  static int _matchCurrencyEnd(String source, int i) {
    var j = _consumeNumber(source, i);
    if (j >= source.length) return -1;
    j = _consumeMagnitudeSuffix(source, j);
    if (j >= source.length) return -1;
    if (!_isRangeJoiner(source[j])) return j;

    // Optional dash-joined range: `-`/`–`/`—` then either `$N`
    // (`$10-$20`, `$5—$10`, `$10k-$20k`) or plain `N` (`$5-10`, `$5–10`,
    // `$10-20k`), each with its own optional magnitude suffix.
    var k = j + 1;
    if (k >= source.length) {
      // A lone trailing dash with nothing after it yet is still ambiguous
      // while streaming: don't hold.
      return -1;
    }
    if (source[k] == _dollar) {
      k++;
      if (k >= source.length) return -1;
      if (!_isDigit(source[k])) return j;
      k = _consumeNumber(source, k);
    } else if (_isDigit(source[k])) {
      k = _consumeNumber(source, k);
    } else {
      // A dash followed by neither `$` nor a digit (`$1-p$`,
      // `$1-\alpha$`): no range ever started, so the currency match ends
      // before the dash.
      return j;
    }
    if (k >= source.length) return -1;
    k = _consumeMagnitudeSuffix(source, k);
    if (k >= source.length) return -1;
    return k;
  }

  /// Consumes a currency number: a run of digits with `.`/`,` allowed
  /// between digits (`5.99`, `1,000`). A separator not followed by another
  /// digit ends the number and stays outside the match, so a sentence-end
  /// `$5.` or `$5,` still terminates here.
  static int _consumeNumber(String source, int i) {
    var j = i;
    while (j < source.length) {
      final c = source[j];
      if (_isDigit(c)) {
        j++;
      } else if ((c == '.' || c == ',') &&
          j + 1 < source.length &&
          _isDigit(source[j + 1])) {
        j += 2;
      } else {
        break;
      }
    }
    return j;
  }

  /// Whether a `$` at [index] can close a LaTeX span, per the pandoc-style
  /// rules on the class doc.
  bool _dollarClosesMath(String source, int index) {
    if (_isEscaped(source, index)) return false;
    if (index == 0) return false;
    if (_isSpace(source[index - 1])) return false;
    final next = index + 1;
    if (next < source.length && _isDigit(source[next])) return false;
    return true;
  }

  static bool _isSpace(String c) =>
      c == ' ' || c == '\t' || c == '\n' || c == '\r';

  static bool _isDigit(String c) {
    final unit = c.codeUnitAt(0);
    return unit >= 0x30 && unit <= 0x39;
  }

  static bool _isPunctuation(String c) => _punctuation.contains(c);

  // `*`, `_` and `~` count so markdown markers keep an adjacent amount
  // currency (`**$20**`, `_$5_`, `~~$5~~`); en/em dashes count so a
  // range's joiner never reads as a math follower. `-` deliberately does
  // NOT count: `$1-p$` and `$2k-1$` are real math.
  static const _punctuation = '.,;:!?)]}%/"\'*_~–—';

  int _consumeDollarSpan(String source, List<AtomicSpan> result, int start) {
    final len = source.length;
    final searchFrom = start + 1;
    final paragraphBoundary = source.indexOf(_paragraphBreak, searchFrom);
    final bounded = paragraphBoundary != -1;
    final limit = bounded ? paragraphBoundary : len;

    var closeAt = -1;
    var j = searchFrom;
    while (j < limit) {
      if (source[j] == _dollar && _dollarClosesMath(source, j)) {
        closeAt = j;
        break;
      }
      j++;
    }

    if (closeAt != -1) {
      final end = closeAt + 1;
      result.add(AtomicSpan(start, end, closed: true));
      return end;
    }
    if (bounded) {
      // The paragraph already ended with no matching close: this `$` was
      // never going to become math here, so it must not hold the cursor.
      return start + 1;
    }
    if (len - start > _unclosedDollarBudget ||
        source.indexOf('\n', searchFrom) != -1) {
      // The paragraph is still open, but a single `$` can't hold the
      // reveal hostage for more than 32 UTF-16 units or past the end of
      // the line - whichever comes first. Past that the `$` was literal
      // all along (a stray, a shell var, ...), so reveal it and move on.
      // `$$`, `\(` and `\[` keep the plain paragraph bound instead.
      return start + 1;
    }
    // The paragraph itself hasn't finished yet - stay ambiguous/withheld
    // only up to what's arrived so far.
    result.add(AtomicSpan(start, len, closed: false));
    return len;
  }

  int _consumeSpan(
    String source,
    List<AtomicSpan> result,
    int start,
    String open,
    String close,
  ) {
    final len = source.length;
    final searchFrom = start + open.length;
    final paragraphBoundary = source.indexOf(_paragraphBreak, searchFrom);
    final bounded = paragraphBoundary != -1;
    final limit = bounded ? paragraphBoundary : len;

    final closeAt = source.indexOf(close, searchFrom);
    if (closeAt != -1 && closeAt < limit) {
      final end = closeAt + close.length;
      result.add(AtomicSpan(start, end, closed: true));
      return end;
    }
    if (bounded) {
      // No matching close turned up before this paragraph ended: not a
      // real span, so don't hold the cursor waiting for one that would
      // only ever appear in some later paragraph.
      return start + open.length;
    }
    result.add(AtomicSpan(start, len, closed: false));
    return len;
  }
}
