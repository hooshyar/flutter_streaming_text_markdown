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
///  * closes an unterminated `**`, `__`, `*`/`_` (skipping list markers and
///    intraword `_`), `~~`, inline code or `***` that already has content
///    after it - but holds back a *lone* trailing marker with nothing after
///    it yet, since more of the same character could still arrive.
///
/// A trailing caret sentinel (see `caret_inline.dart`) is stripped before
/// any of the above runs, then re-appended only when the mended tail does
/// not end inside an open fence/math block - so the sentinel never reaches
/// a `codeBuilder`'s `code` string.
String mend(String text, {required bool isComplete}) {
  if (isComplete || text.isEmpty) return text;

  final hasSentinel = text.endsWith(caretSentinel);
  final body =
      hasSentinel ? text.substring(0, text.length - caretSentinel.length) : text;

  final split = settledSplitOffset(body);
  final settled = body.substring(0, split);
  final tail = body.substring(split);

  final mended = _mendTail(tail);
  final out = settled + mended.text;
  return hasSentinel && !mended.insideOpenBlock ? '$out$caretSentinel' : out;
}

class _TailMend {
  const _TailMend(this.text, {required this.insideOpenBlock});

  final String text;
  final bool insideOpenBlock;
}

_TailMend _mendTail(String tail) {
  if (tail.isEmpty) return _TailMend(tail, insideOpenBlock: false);

  final fence = _mendFence(tail);
  if (fence.handled) {
    return _TailMend(fence.text, insideOpenBlock: fence.insideOpenBlock);
  }

  final held = _holdMarkerOnlyLine(tail);
  if (held != null) {
    return _TailMend(held, insideOpenBlock: false);
  }

  var s = tail;
  s = _holdOpenHtmlTag(s);
  s = _holdOpenImage(s);
  s = _rewriteOpenLink(s);

  final math = _rewriteOpenMath(s);
  if (math.isFence) {
    return _TailMend(math.text, insideOpenBlock: true);
  }
  s = math.text;

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
      hasTrailingNewline
          ? ''
          : (lines.isEmpty ? '' : lines.removeLast());

  var inFence = false;
  for (final line in lines) {
    if (line.trimLeft().startsWith('```')) inFence = !inFence;
  }

  if (inFence) {
    // Already inside a real, previously-opened fence - `gpt_markdown` grows
    // the code block itself from here. Never touch a byte of it.
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

final RegExp _headingMarkerOnly = RegExp(r'^#{1,6}$');
final RegExp _bulletMarkerOnly = RegExp(r'^[-*+]$');
final RegExp _orderedMarkerOnly = RegExp(r'^\d+\.$');
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
  if (last.closed || last.end != s.length) return _MathRewrite(s, isFence: false);
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

/// Closes an unterminated `**`, `__`, `*`/`_`, `~~`, inline code or `***`
/// that already has content after it, by appending the matching closer.
/// A *lone* trailing delimiter with nothing after it yet - the marker
/// itself is the last thing in [s] - is held back instead: one more of the
/// same character could still turn it into a different marker entirely.
///
/// Skips a `*`/`-`/`+` or `N.` list marker at the start of a line (followed
/// by a space/tab) and an intraword `_` (flanked by word characters on both
/// sides) - neither ever opens emphasis.
String _closeOrHoldInlineMarkers(String s) {
  var boldItalicOpen = false;
  var boldOpen = false;
  var underBoldOpen = false;
  var strikeOpen = false;
  var emOpen = false;
  var underEmOpen = false;
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
    if (s.startsWith('__', i)) {
      underBoldOpen = !underBoldOpen;
      i += 2;
      continue;
    }
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
      emOpen = !emOpen;
      i++;
      continue;
    }
    if (c == '_') {
      final prev = i > 0 ? s[i - 1] : '';
      final next = i + 1 < n ? s[i + 1] : '';
      if (!(_isWordChar(prev) && _isWordChar(next))) {
        underEmOpen = !underEmOpen;
      }
      i++;
      continue;
    }
    i++;
  }

  final candidates = <String>[
    if (boldItalicOpen) '***',
    if (codeOpen) '`',
    if (boldOpen) '**',
    if (underBoldOpen) '__',
    if (strikeOpen) '~~',
    if (emOpen) '*',
    if (underEmOpen) '_',
  ];
  if (candidates.isEmpty) return s;

  for (final token in candidates) {
    if (s.endsWith(token)) {
      return s.substring(0, s.length - token.length);
    }
  }
  return s + candidates.join();
}
