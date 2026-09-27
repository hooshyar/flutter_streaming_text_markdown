import 'package:gpt_markdown/gpt_markdown.dart' show settledSplitOffset;

import '../engine/atomic_spans.dart';
import 'caret_inline.dart' show caretSentinel;

/// Mends the tail of a still-streaming markdown [text] so it never renders a
/// raw, half-typed marker while more characters are on the way.
///
/// Replaces `withholdOpenFence`. Returns [text] unchanged whenever
/// [isComplete] is true - a finished document is never touched. While
/// incomplete, only the tail *after* `gpt_markdown`'s own
/// [settledSplitOffset] is inspected: everything before that offset is
/// already a settled, complete construct (blank-line terminated), so it can
/// never need mending.
///
/// Inside that tail, `mend`:
///  * passes an already-open ``` fence straight through, so `gpt_markdown`
///    renders it as a growing `MdCodeBlock(closed: false)` - but holds back
///    a fence-opener line (or a bare 1-2 backtick run) that has no trailing
///    newline yet, since it is still ambiguous whether it will become a
///    fence, inline code, or plain text;
///  * holds back marker-only lines (`#`..`######`, `-`, `*`, `+`, `1.`, `>`,
///    a setext/hr `--`/`==` run) that have no content after them yet;
///  * holds back an open `<tag` with no closing `>`, and an open
///    `![alt](partial` image;
///  * rewrites an open `[text` / `[text](partial` link down to just its
///    text, since it can't be tapped yet anyway;
///  * rewrites an open `$$...` into a `math-pending` fenced block, and an
///    open inline `$x` into `` `x` ``, using [AtomicSpanDetector] to find
///    them (currency-shaped `$` is never touched - that stays
///    [AtomicSpanDetector]'s call);
///  * closes an unterminated `**`, `*`, `~~`, inline code or `***` that
///    already has content after it (skipping list markers and intraword
///    `*`) - but holds back a *lone* trailing marker with nothing after it
///    yet, since more of the same character could still arrive. `_`/`__`
///    are never tracked at all: `gpt_markdown` 1.3.0 doesn't render either
///    as emphasis, so "closing" one would only invent extra raw
///    underscores.
///
/// A trailing caret sentinel (see `caret_inline.dart`) is stripped before
/// any of the above runs, then re-appended only when the mended tail does
/// not end inside an open fence/math block - so the sentinel never reaches
/// a `codeBuilder`'s `code` string.
String mend(
  String text, {
  required bool isComplete,
  bool latexEnabled = false,
}) {
  if (isComplete || text.isEmpty) return text;

  final hasSentinel = text.endsWith(caretSentinel);
  final body =
      hasSentinel
          ? text.substring(0, text.length - caretSentinel.length)
          : text;

  // `settledSplitOffset` is `gpt_markdown`'s own judgment of what's
  // definitely finished, from ITS parser's point of view - a closed
  // `[text]`/`![alt]` pair with nothing after it yet reads as complete,
  // unambiguous plain-bracket text to `gpt_markdown` (it has no notion that
  // *we* are holding it in case a `(` arrives next), so it can end up
  // inside `settled` and never reach `_mendTail`'s tail-only pipeline at
  // all. Truncate that one ambiguous case off the very end of the whole
  // body FIRST, before `gpt_markdown` ever gets a say - see B1F1 round 2.
  // Same reasoning applies to a table header row that isn't the very first
  // thing in the document (B1F1 round 3): `gpt_markdown` has no notion of
  // "might still become a table" either, so it too must be checked against
  // the whole body, not just the post-split tail.
  final linkSafeBody =
      _isInsideCodeContext(body) ? body : _holdImageOrLinkStart(body);
  final safeBody = _holdIncompleteTableHeader(linkSafeBody) ?? linkSafeBody;

  final split = settledSplitOffset(safeBody);
  final settled = safeBody.substring(0, split);
  final tail = safeBody.substring(split);

  final mended = _mendTail(tail, latexEnabled: latexEnabled);
  final out = settled + mended.text;
  return hasSentinel && !mended.insideOpenBlock ? '$out$caretSentinel' : out;
}

class _TailMend {
  const _TailMend(this.text, {required this.insideOpenBlock});

  final String text;
  final bool insideOpenBlock;
}

_TailMend _mendTail(String tail, {required bool latexEnabled}) {
  if (tail.isEmpty) return _TailMend(tail, insideOpenBlock: false);

  final table = _holdIncompleteTableHeader(tail);
  if (table != null) {
    return _TailMend(table, insideOpenBlock: false);
  }

  final fence = _mendFence(tail);
  if (fence.handled) {
    return _TailMend(fence.text, insideOpenBlock: fence.insideOpenBlock);
  }

  final held = _holdMarkerOnlyLine(tail);
  if (held != null) {
    return _TailMend(held, insideOpenBlock: false);
  }

  var s = tail;
  // None of the HTML-tag/image/link holds and rewrites below make sense
  // inside an open code fence or inline code span - `<`, `!`, `[`, `]`, `(`
  // are all just literal characters there (e.g. Rust's `vec![1, 2, 3]`
  // written inline as `` `vec![1, 2, 3]` ``). Skip the whole block (B1F1
  // round 3, non-blocking item 1).
  if (!_isInsideCodeContext(s)) {
    s = _holdOpenHtmlTag(s);
    s = _holdImageOrLinkStart(s);
    s = _holdOpenImage(s);
    s = _rewriteOpenLink(s);
  }

  // Only ours to rewrite when the caller has LaTeX recognition on - with it
  // off (the default), a `$` is never touched here, so a plain variable
  // like `$count` keeps its `$` instead of losing it to a bogus inline-code
  // rewrite (B1F1 bug #2).
  if (latexEnabled) {
    final math = _rewriteOpenMath(s);
    if (math.isFence) {
      return _TailMend(math.text, insideOpenBlock: true);
    }
    s = math.text;
  }

  s = _closeOrHoldInlineMarkers(s);
  return _TailMend(s, insideOpenBlock: false);
}

class _FenceCheck {
  const _FenceCheck({
    required this.text,
    required this.insideOpenBlock,
    required this.handled,
  });

  final String text;
  final bool insideOpenBlock;

  /// Whether the fence check alone fully decided the outcome - the rest of
  /// [_mendTail]'s pipeline must not run (it could corrupt code content).
  final bool handled;
}

final RegExp _bareBacktickRun = RegExp(r'^`{1,2}$');
final RegExp _fenceOpenerInProgress = RegExp(r'^`{3,}[\w-]*$');

_FenceCheck _mendFence(String tail) {
  final hasTrailingNewline = tail.endsWith('\n');
  final lines = tail.split('\n');
  final partialLine =
      hasTrailingNewline ? '' : (lines.isEmpty ? '' : lines.removeLast());

  var inFence = false;
  for (final line in lines) {
    if (line.trimLeft().startsWith('```')) inFence = !inFence;
  }

  if (inFence) {
    // Already inside a real, previously-opened fence - `gpt_markdown` grows
    // the code block itself from here. Never touch a byte of it, EXCEPT a
    // trailing backtick-only partial line with no newline yet: that could
    // still be the closing ``` in progress (1 or 2 backticks so far), so
    // showing it now would flash a stray backtick inside the code content
    // for a frame (B1F1 round 3, non-blocking item 2).
    if (!hasTrailingNewline &&
        _bareBacktickRun.hasMatch(partialLine.trimLeft())) {
      final cut = tail.length - partialLine.length;
      return _FenceCheck(
        text: tail.substring(0, cut),
        insideOpenBlock: true,
        handled: true,
      );
    }
    return _FenceCheck(text: tail, insideOpenBlock: true, handled: true);
  }

  if (!hasTrailingNewline) {
    final trimmed = partialLine.trimLeft();
    if (_bareBacktickRun.hasMatch(trimmed) ||
        _fenceOpenerInProgress.hasMatch(trimmed)) {
      final cut = tail.length - partialLine.length;
      return _FenceCheck(
        text: tail.substring(0, cut),
        insideOpenBlock: false,
        handled: true,
      );
    }
  }

  return const _FenceCheck(text: '', insideOpenBlock: false, handled: false);
}

// A "table row-like" line is any line that starts with `|` (after optional
// leading indentation) - it does NOT need a matching trailing `|` too: GFM
// tables tolerate a missing outer pipe on either edge, and holding only
// when the line happened to end in `|` let a bare `| Name | Age` (no
// trailing pipe) leak straight through as raw text.
final RegExp _tableRowLike = RegExp(r'^[ \t]*\|');
final RegExp _tableSepComplete = RegExp(
  r'^\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)+\|?\s*$',
);
final RegExp _tableSepChars = RegExp(r'^[|:\- \t]*$');

/// Holds back a table header row until its separator row is fully typed -
/// GFM only recognizes a table once the separator line commits, so without
/// this a bare header (or one with a still-typing separator) would render
/// for a frame or two as a raw pipe-delimited line instead. Returns `null`
/// when the trailing shape isn't a header/partial-separator pair at all.
///
/// Runs against the LAST BLOCK of whatever string it's given, regardless of
/// what precedes it (a paragraph, a heading, a list, nothing) - callers pass
/// it the *whole* body (see B1F1 round 3: calling it only on the tail after
/// `settledSplitOffset` missed a table that isn't the very first thing in
/// the document, since `gpt_markdown`'s own settled/unsettled split has no
/// notion of "might still become a table").
String? _holdIncompleteTableHeader(String tail) {
  final hasTrailingNewline = tail.endsWith('\n');
  final body = hasTrailingNewline ? tail.substring(0, tail.length - 1) : tail;
  final lines = body.split('\n');
  if (lines.isEmpty) return null;

  if (!hasTrailingNewline) {
    // The very last line is still being typed. It might be a table's very
    // first row (nothing above it needs to be a row too - anything at all
    // may precede a table's header), or a separator-in-progress under an
    // already-committed header row.
    final partial = lines.removeLast();
    if (!_tableRowLike.hasMatch(partial)) return null;

    final linePreceding = lines.isEmpty ? null : lines.last;
    if (linePreceding != null && _tableRowLike.hasMatch(linePreceding)) {
      // The line right above is ALSO row-shaped - the partial line reads as
      // a separator-in-progress under it, unless it already has non-
      // separator content (then it's an ordinary data row of an
      // already-settled table, not our concern).
      if (_tableSepChars.hasMatch(partial) &&
          !_tableSepComplete.hasMatch(partial.trim())) {
        final cut = tail.length - partial.length - 1 - linePreceding.length;
        return tail.substring(0, cut < 0 ? 0 : cut);
      }
      return null;
    }

    // Nothing row-shaped directly above - this is a table's first (header)
    // row, still being typed. Hold just this line, whatever precedes it.
    return tail.substring(0, tail.length - partial.length);
  }

  // Trailing newline: the last committed line might be a bare header with
  // nothing after it yet at all. A separator line (only `|`/`:`/`-`/space)
  // also happens to match the generic row shape, so exclude it explicitly -
  // once a real separator has landed, the header is free to render.
  final header = lines.last;
  if (header.isNotEmpty &&
      _tableRowLike.hasMatch(header) &&
      !_tableSepChars.hasMatch(header)) {
    final cut = tail.length - 1 - header.length;
    return tail.substring(0, cut < 0 ? 0 : cut);
  }
  return null;
}

final RegExp _headingMarkerOnly = RegExp(r'^#{1,6}$');
final RegExp _bulletMarkerOnly = RegExp(r'^[-*+]$');
final RegExp _orderedMarkerOnly = RegExp(r'^\d+\.$');
// A bare digit run with no `.` yet - one more digit or a `.` could still
// turn this into an ordered-list marker (`1` -> `12` -> `12.`), so it's held
// back exactly like the already-dotted `_orderedMarkerOnly` case.
final RegExp _digitRunOnly = RegExp(r'^\d+$');
final RegExp _quoteMarkerOnly = RegExp(r'^>+$');
final RegExp _setextOrHrRun = RegExp(r'^[-=]{1,}$');

/// Holds back a trailing marker-only line (heading/list/quote/setext/hr)
/// that has no content after it yet, so the reveal never flashes an empty
/// bullet, heading or quote marker. Returns `null` when the trailing line
/// isn't one of these (nothing to hold).
String? _holdMarkerOnlyLine(String tail) {
  if (tail.endsWith('\n')) return null;
  final lastNewline = tail.lastIndexOf('\n');
  final partialLine = tail.substring(lastNewline + 1);
  final trimmed = partialLine.trimLeft();
  if (trimmed.isEmpty) return null;

  final isMarkerOnly =
      _headingMarkerOnly.hasMatch(trimmed) ||
      _bulletMarkerOnly.hasMatch(trimmed) ||
      _orderedMarkerOnly.hasMatch(trimmed) ||
      _digitRunOnly.hasMatch(trimmed) ||
      _quoteMarkerOnly.hasMatch(trimmed) ||
      _setextOrHrRun.hasMatch(trimmed);
  if (!isMarkerOnly) return null;

  return tail.substring(0, lastNewline + 1);
}

final RegExp _openHtmlTag = RegExp(r'<[a-zA-Z!/][^<>]*$');

/// Holds back a trailing `<tag` with no closing `>` yet.
String _holdOpenHtmlTag(String s) {
  final match = _openHtmlTag.firstMatch(s);
  if (match == null) return s;
  return s.substring(0, match.start);
}

final RegExp _openImageAltInProgress = RegExp(r'!\[[^\]]*$');
final RegExp _closedBracketNoParenYet = RegExp(r'!?\[[^\[\]]*\]$');
final RegExp _trailingBang = RegExp(r'!$');

/// Holds back the start of a possible image/link that hasn't resolved
/// enough to know what it will become:
///  * `![alt` with no closing `]` yet - the alt text is still being typed,
///    so this must run *before* [_rewriteOpenLink] would otherwise mistake
///    it for a bare `[text` link and drop just the `[`, leaving a stray `!`;
///  * a closed `[text]`/`![alt]` with nothing after it yet - one more `(`
///    would turn it into a tappable link/image, so it stays ambiguous;
///  * a lone trailing `!` - one more `[` would start an image.
///
/// Never applied inside an open code fence or inline code span (`[`/`!`/`]`
/// are just literal characters there, e.g. Rust's `vec![1, 2, 3]` written
/// as `` `vec![1, 2, 3]` `` - callers check [_isInsideCodeContext] first.
String _holdImageOrLinkStart(String s) {
  final altInProgress = _openImageAltInProgress.firstMatch(s);
  if (altInProgress != null) {
    return s.substring(0, altInProgress.start);
  }
  final closedPair = _closedBracketNoParenYet.firstMatch(s);
  if (closedPair != null) {
    return s.substring(0, closedPair.start);
  }
  if (_trailingBang.hasMatch(s)) {
    return s.substring(0, s.length - 1);
  }
  return s;
}

/// Whether the very end of [s] sits inside an open ``` fence or an open
/// inline `` ` `` code span - in either case, markdown-ish punctuation
/// (`[`, `!`, `]`) inside it is just literal text and must never be held or
/// rewritten by the image/link start check.
bool _isInsideCodeContext(String s) {
  var inFence = false;
  var codeOpen = false;
  for (final line in s.split('\n')) {
    if (line.trimLeft().startsWith('```')) {
      inFence = !inFence;
      codeOpen = false;
      continue;
    }
    if (inFence) continue;
    var i = 0;
    final n = line.length;
    while (i < n) {
      final c = line[i];
      if (c == '\\' && i + 1 < n) {
        i += 2;
        continue;
      }
      if (c == '`') {
        codeOpen = !codeOpen;
        i++;
        continue;
      }
      i++;
    }
  }
  return inFence || codeOpen;
}

final RegExp _openImage = RegExp(r'!\[[^\]]*\]\([^)]*$');

/// Holds back a trailing `![alt](partial` image entirely.
String _holdOpenImage(String s) {
  final match = _openImage.firstMatch(s);
  if (match == null) return s;
  return s.substring(0, match.start);
}

final RegExp _linkWithPartialUrl = RegExp(r'\[([^\]]*)\]\([^)]*$');
final RegExp _bareOpenLink = RegExp(r'\[([^\]]*)$');

/// Rewrites a trailing open link down to just its text - `[text](partial`
/// and bare `[text` both become `text`, since neither can be tapped yet.
String _rewriteOpenLink(String s) {
  final withUrl = _linkWithPartialUrl.firstMatch(s);
  if (withUrl != null) {
    return s.substring(0, withUrl.start) + (withUrl.group(1) ?? '');
  }
  final bareOpen = _bareOpenLink.firstMatch(s);
  if (bareOpen != null) {
    return s.substring(0, bareOpen.start) + (bareOpen.group(1) ?? '');
  }
  return s;
}

class _MathRewrite {
  const _MathRewrite(this.text, {required this.isFence});

  final String text;

  /// Whether [text] now ends in an open `math-pending` fence - the rest of
  /// [_mendTail]'s pipeline must not append anything after it.
  final bool isFence;
}

/// Rewrites a trailing open `$$...`/`$x` LaTeX span found by
/// [AtomicSpanDetector.spans] - `$$...` becomes an open `math-pending`
/// fenced block, `$x` becomes `` `x` ``. Currency-shaped `$` never shows up
/// here at all: [AtomicSpanDetector] already excludes it.
_MathRewrite _rewriteOpenMath(String s) {
  final spans = const AtomicSpanDetector().spans(s);
  if (spans.isEmpty) return _MathRewrite(s, isFence: false);

  final last = spans.last;
  if (last.closed || last.end != s.length) {
    return _MathRewrite(s, isFence: false);
  }
  // Only a `$`/`$$` delimiter is ours to rewrite here - a native `\(`/`\[`
  // span is left for `gpt_markdown`'s own (literal-text) fallback.
  if (!s.startsWith(r'$', last.start)) return _MathRewrite(s, isFence: false);

  final isBlock = s.startsWith(r'$$', last.start);
  final delimiterLength = isBlock ? 2 : 1;
  final before = s.substring(0, last.start);
  final inner = s.substring(last.start + delimiterLength, last.end);

  if (isBlock) {
    return _MathRewrite('$before```math-pending\n$inner', isFence: true);
  }
  return _MathRewrite('$before`$inner`', isFence: false);
}

bool _isWordChar(String c) {
  if (c.isEmpty) return false;
  final unit = c.codeUnitAt(0);
  return (unit >= 0x30 && unit <= 0x39) || // 0-9
      (unit >= 0x41 && unit <= 0x5A) || // A-Z
      (unit >= 0x61 && unit <= 0x7A) || // a-z
      unit == 0x5F; // _
}

/// Closes an unterminated `**`, `*`, `~~`, inline code or `***` that
/// already has content after it, by appending the matching closer(s). A
/// *lone* trailing delimiter with nothing after it yet is held back instead
/// (dropped from the returned text): one more of the same character could
/// still turn it into a different marker entirely. Holding one trailing
/// token never suppresses closers still owed to other, earlier-opened
/// markers - those are appended regardless (see the "Hello **bold*" case in
/// PHASE-B1-PLAN.md's B1F1 bug #3).
///
/// Skips a `*`/`-`/`+` or `N.` list marker at the start of a line (followed
/// by a space/tab). A single `*` only opens/closes emphasis when it is
/// left-/right-flanking per CommonMark and not part of an intraword run
/// (`a*b` never opens) - except for the very last character of [s], which
/// is always ambiguous (more of the run may still arrive) and is handled by
/// the trailing-hold step below instead.
///
/// Neither `_` nor `__` is ever treated as an emphasis delimiter here: `_`
/// is far too common in ordinary prose and identifiers (`snake_case`,
/// `_private`, `dunder__`) to safely guess whether an unclosed one will
/// ever close, and `gpt_markdown` 1.3.0 doesn't actually render `_`/`__`
/// emphasis at all - it always shows the underscores literally - so
/// "closing" either one just invents extra raw underscores that were never
/// going to be styled anyway.
String _closeOrHoldInlineMarkers(String s) {
  var boldItalicOpen = false;
  var boldOpen = false;
  var strikeOpen = false;
  var emOpen = false;
  var codeOpen = false;

  var i = 0;
  final n = s.length;
  var atLineStart = true;

  while (i < n) {
    final c = s[i];
    if (c == '\n') {
      atLineStart = true;
      i++;
      continue;
    }
    if (c == '\\' && i + 1 < n) {
      i += 2;
      atLineStart = false;
      continue;
    }
    if (codeOpen) {
      if (c == '`') codeOpen = false;
      i++;
      continue;
    }
    if (s.startsWith('```', i)) {
      // Fences are fully handled upstream and never reach this scanner;
      // skip defensively rather than mis-toggle on a stray triple-backtick.
      i += 3;
      atLineStart = false;
      continue;
    }
    if (atLineStart) {
      var j = i;
      while (j < n && (s[j] == ' ' || s[j] == '\t')) {
        j++;
      }
      if (j < n) {
        final mc = s[j];
        if ((mc == '*' || mc == '-' || mc == '+') &&
            j + 1 < n &&
            (s[j + 1] == ' ' || s[j + 1] == '\t')) {
          i = j + 2;
          atLineStart = false;
          continue;
        }
        final ordered = RegExp(r'^\d+\.[ \t]').matchAsPrefix(s, j);
        if (ordered != null) {
          i = ordered.end;
          atLineStart = false;
          continue;
        }
      }
    }
    if (c != ' ' && c != '\t') atLineStart = false;

    if (s.startsWith('***', i)) {
      boldItalicOpen = !boldItalicOpen;
      i += 3;
      continue;
    }
    if (s.startsWith('**', i)) {
      boldOpen = !boldOpen;
      i += 2;
      continue;
    }
    // `__` is never tracked - see the doc comment above.
    if (s.startsWith('~~', i)) {
      strikeOpen = !strikeOpen;
      i += 2;
      continue;
    }
    if (c == '`') {
      codeOpen = true;
      i++;
      continue;
    }
    if (c == '*') {
      final atEnd = i == n - 1;
      if (atEnd) {
        // The very last character seen so far - inherently ambiguous (one
        // more '*' could still arrive and turn this into '**'/'***'), so
        // always flip like a plain toggle; the trailing-hold step below
        // decides whether to show or withhold it.
        emOpen = !emOpen;
      } else {
        final prev = i > 0 ? s[i - 1] : '';
        final next = s[i + 1];
        final intraword = _isWordChar(prev) && _isWordChar(next);
        if (!intraword) {
          if (!emOpen) {
            final leftFlanking = next != ' ' && next != '\t' && next != '\n';
            if (leftFlanking) emOpen = true;
          } else {
            final rightFlanking =
                prev.isNotEmpty && prev != ' ' && prev != '\t' && prev != '\n';
            if (rightFlanking) emOpen = false;
          }
        }
      }
      i++;
      continue;
    }
    // A lone '_' is never tracked as an emphasis delimiter - see the doc
    // comment above.
    i++;
  }

  final candidates = <String>[
    if (boldItalicOpen) '***',
    if (codeOpen) '`',
    if (boldOpen) '**',
    if (strikeOpen) '~~',
    if (emOpen) '*',
  ];

  // A lone trailing '~' is always ambiguous while streaming - one more '~'
  // arriving would turn it into a strike-through delimiter, an entirely
  // different construct - so it's held back regardless of whether a strike
  // span happens to be open already.
  var result = s;
  if (result.endsWith('~') && !result.endsWith('~~')) {
    result = result.substring(0, result.length - 1);
  }

  if (candidates.isEmpty) return result;

  final remaining = List<String>.from(candidates);
  for (final token in candidates) {
    if (result.endsWith(token)) {
      result = result.substring(0, result.length - token.length);
      remaining.remove(token);
      break;
    }
  }
  return result + remaining.join();
}
