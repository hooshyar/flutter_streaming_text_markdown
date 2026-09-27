// Regression coverage for PHASE-B1-PLAN.md's B1F1 bug #3:
// `_closeOrHoldInlineMarkers` (lib/src/render/mend.dart) used to invent
// characters and styles that were never in the source while a document was
// still streaming. Every case here reproduces one of the five failures
// listed in the bug report and FAILS on the pre-fix code (verified in a
// scratch worktree before landing this fix), because the old code either:
//   * treated any single `_`/`*` as an emphasis delimiter with no left-/
//     right-flanking or intraword check at all, or
//   * `return`ed immediately after trimming the one ambiguous trailing
//     token, dropping the closer still owed to an earlier, still-open span.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/frames.dart';

/// All plain text currently on screen, caret sentinel stripped.
String _visible(WidgetTester tester) {
  final parts = <String>[];
  for (final element
      in find.byWidgetPredicate((w) => w is RichText).evaluate()) {
    final text = (element.widget as RichText).text.toPlainText();
    if (text.trim().isNotEmpty) parts.add(text);
  }
  return parts.join('\n').replaceAll('', '').replaceAll('￼', '');
}

/// Whether any span currently on screen renders in italics.
bool _anyItalic(WidgetTester tester) {
  var found = false;
  void visit(InlineSpan span, TextStyle? inherited) {
    if (span is TextSpan) {
      final style = inherited?.merge(span.style) ?? span.style;
      if (style?.fontStyle == FontStyle.italic &&
          (span.text ?? '').isNotEmpty) {
        found = true;
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        visit(child, style);
      }
    }
  }

  for (final element
      in find.byWidgetPredicate((w) => w is RichText).evaluate()) {
    visit((element.widget as RichText).text, null);
  }
  return found;
}

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(child: SizedBox(width: 600, child: child)),
  ),
);

/// Streams [source] one character at a time through [StreamingText] with
/// markdown on, pumping a real 16ms frame after each character (plus a
/// settling tail), calling [onFrame] with the visible text after every
/// pump so the caller can assert invariants that must hold on EVERY frame,
/// not just the final one.
Future<void> _streamDefault(
  WidgetTester tester,
  String source,
  void Function(WidgetTester tester, String visible) onFrame,
) async {
  final controller = StreamController<String>();
  await tester.pumpWidget(
    _host(
      StreamingText(text: '', stream: controller.stream, markdownEnabled: true),
    ),
  );
  for (var i = 0; i < source.length; i++) {
    controller.add(source[i]);
    await tester.pump(frameInterval);
    onFrame(tester, _visible(tester));
  }
  await controller.close();
  await pumpFrames(tester, 40);
  onFrame(tester, _visible(tester));
}

/// Same as [_streamDefault] but through `.typewriter()` (legacy character
/// mode) driven by `text:`/`typingSpeed`, not a stream - this is the mode
/// the bug report calls out by name for the "Hello **bold*" case.
Future<void> _streamTypewriter(
  WidgetTester tester,
  String source,
  void Function(WidgetTester tester, String visible) onFrame,
) async {
  await tester.pumpWidget(
    _host(
      StreamingTextMarkdown.typewriter(
        text: source,
        markdownEnabled: true,
        typingSpeed: frameInterval,
      ),
    ),
  );
  for (var i = 0; i <= source.length; i++) {
    await tester.pump(frameInterval);
    onFrame(tester, _visible(tester));
  }
  await pumpFrames(tester, 40);
  onFrame(tester, _visible(tester));
}

/// Same as [_streamDefault] but explicit `RevealMode.wordFade` - B1F1
/// round 3's report calls this mode out by name alongside smooth/typewriter
/// for the table-header leak.
Future<void> _streamWordFade(
  WidgetTester tester,
  String source,
  void Function(WidgetTester tester, String visible) onFrame,
) async {
  final controller = StreamController<String>();
  await tester.pumpWidget(
    _host(
      StreamingText(
        text: '',
        stream: controller.stream,
        markdownEnabled: true,
        revealMode: RevealMode.wordFade,
      ),
    ),
  );
  for (var i = 0; i < source.length; i++) {
    controller.add(source[i]);
    await tester.pump(frameInterval);
    onFrame(tester, _visible(tester));
  }
  await controller.close();
  await pumpFrames(tester, 40);
  onFrame(tester, _visible(tester));
}

void main() {
  testWidgets('snake_case / _private prose never gets an invented trailing _', (
    tester,
  ) async {
    const source = 'Use snake_case and _private names in this module always. ';
    var sawTrailingUnderscore = false;
    await _streamDefault(tester, source, (t, visible) {
      if (visible.trimRight().endsWith('_') &&
          !source.startsWith(visible.trimRight())) {
        sawTrailingUnderscore = true;
      }
      // Stronger check: an underscore mend ever appends is never present
      // in the source at that exact position, so any trailing `_` that
      // isn't a genuine prefix of the source is proof of invention.
      if (visible.isNotEmpty &&
          visible.endsWith('_') &&
          !source.startsWith(visible)) {
        sawTrailingUnderscore = true;
      }
    });
    expect(sawTrailingUnderscore, isFalse);
  });

  testWidgets('a*b never goes italic mid-stream', (tester) async {
    const source = 'Use a*b + c for the sum and then we are done. ';
    var sawItalic = false;
    await _streamDefault(tester, source, (t, visible) {
      if (_anyItalic(t)) sawItalic = true;
    });
    expect(sawItalic, isFalse);
  });

  testWidgets('2 * 3 multiplication never flashes "* *"', (tester) async {
    const source = 'Compute 2 * 3 = 6 and then 4 * 5 = 20, done. ';
    var sawDoubleStarFlash = false;
    await _streamDefault(tester, source, (t, visible) {
      if (visible.contains('* *')) sawDoubleStarFlash = true;
      // Also make sure no extra '*' beyond what's been typed so far shows:
      // the count of '*' rendered is never more
      // than the count of '*' in the longest prefix of source no longer
      // than what's visible.
      final visibleStars = '*'.allMatches(visible).length;
      final prefix = source.substring(
        0,
        visible.length.clamp(0, source.length),
      );
      final prefixStars = '*'.allMatches(prefix).length;
      if (visibleStars > prefixStars) sawDoubleStarFlash = true;
    });
    expect(sawDoubleStarFlash, isFalse);
  });

  for (final mode in ['default', 'typewriter']) {
    testWidgets('Hello **bold* never leaves a raw ** visible ($mode)', (
      tester,
    ) async {
      const source = 'Hello **bold*';
      var sawRawDoubleStar = false;
      void check(WidgetTester t, String visible) {
        // A raw, unclosed ** is a run of exactly two asterisks that is not
        // immediately followed by more content wrapped and re-closed -
        // simplest robust check: gpt_markdown never leaves literal '**' in
        // the plain-text output once mend has run (it either shows none,
        // or fully-closed bold text with no literal asterisks at all,
        // since GptMarkdown strips matched bold delimiters when styling).
        if (visible.contains('**')) sawRawDoubleStar = true;
      }

      if (mode == 'default') {
        await _streamDefault(tester, source, check);
      } else {
        await _streamTypewriter(tester, source, check);
      }
      expect(sawRawDoubleStar, isFalse);
    });
  }

  for (final mode in ['default', 'typewriter']) {
    testWidgets('a ~~gone~ never becomes ~~gone~~~ ($mode)', (tester) async {
      const source = 'a ~~gone~ and more text follows to be sure. ';
      var sawTripleTilde = false;
      void check(WidgetTester t, String visible) {
        if (visible.contains('~~~')) sawTripleTilde = true;
      }

      if (mode == 'default') {
        await _streamDefault(tester, source, check);
      } else {
        await _streamTypewriter(tester, source, check);
      }
      expect(sawTripleTilde, isFalse);
    });
  }

  // B1F1 round 2 BLOCKER: char-mode (typewriter, 1-char-chunk) coverage for
  // the underscore case - the default-mode-only widget test above happened
  // to pass on the buggy base too (gpt_markdown's own handling masked the
  // exact mend() output at the widget level); this adds the char-mode leg.
  testWidgets('snake_case / _private prose never gets an invented trailing _ '
      '(typewriter, char mode)', (tester) async {
    const source = 'Use snake_case and _private names in this module always. ';
    var sawTrailingUnderscore = false;
    await _streamTypewriter(tester, source, (t, visible) {
      if (visible.isNotEmpty &&
          visible.endsWith('_') &&
          !source.startsWith(visible)) {
        sawTrailingUnderscore = true;
      }
    });
    expect(sawTrailingUnderscore, isFalse);
  });

  // --- B1F1 round 2, item 1: non-blocking, stop tracking __ ---------------
  testWidgets(
    "Hello __bold_ never becomes __bold___ (gpt_markdown doesn't render "
    '__ anyway)',
    (tester) async {
      const source = 'Hello __bold_ and more text keeps going here. ';
      var sawInventedUnderscores = false;
      await _streamTypewriter(tester, source, (t, visible) {
        // Any run of 3+ underscores is definitely invented - the source
        // never has more than 2 in a row.
        if (RegExp('_{3,}').hasMatch(visible)) sawInventedUnderscores = true;
      });
      expect(sawInventedUnderscores, isFalse);
    },
  );

  // --- B1F1 round 2, item 2: broaden table header holding ------------------
  for (final mode in ['default', 'typewriter']) {
    testWidgets('| Name | Age (no closing pipe) never renders raw before the '
        'separator completes ($mode)', (tester) async {
      const source = '| Name | Age\n|---|---|\n| Bob | 42 |\n\nDone with it. ';
      // Once the table renders as a real widget, the separator's dashes
      // are never literal plain text again - track "separator complete"
      // by stream position instead (frames are called once per character
      // pushed, in order).
      final sepCompleteAt = source.indexOf('|---|---|') + '|---|---|'.length;
      var charsPushed = 0;
      var sawRawPipeBeforeSeparator = false;
      void check(WidgetTester t, String visible) {
        charsPushed++;
        if (charsPushed < sepCompleteAt && visible.contains('|')) {
          sawRawPipeBeforeSeparator = true;
        }
      }

      if (mode == 'default') {
        await _streamDefault(tester, source, check);
      } else {
        await _streamTypewriter(tester, source, check);
      }
      expect(sawRawPipeBeforeSeparator, isFalse);
    });
  }

  // --- B1F1 round 2, item 3: typewriter one-frame flashes ------------------
  testWidgets('a lone ~ (no strike ever opens) never flashes before settling '
      '(typewriter)', (tester) async {
    const source = 'price ~5 or so, thanks for asking about it today. ';
    final frames = <String>[];
    await _streamTypewriter(tester, source, (t, visible) {
      frames.add(visible);
    });
    // The single '~' must never appear alone as the very last visible
    // character mid-stream (that is the one-frame flash) - once it is
    // followed by '5' it is unambiguous ordinary text and may show.
    for (final f in frames) {
      if (f.endsWith('~')) {
        fail('lone trailing ~ flashed on screen: "$f"');
      }
    }
    expect(frames.last.trimRight(), source.trimRight());
  });

  testWidgets(
    '[docs] with no ( yet never flashes as a raw bracket pair (typewriter)',
    (tester) async {
      const source = 'See [docs] for more information right now please. ';
      // Track "is the bracket pair still ambiguous" by stream position, not
      // by pattern-matching the rendered text: gpt_markdown trims trailing
      // whitespace when it paints, so "See [docs]" (bracket pair, nothing
      // after it yet) and "See [docs] " (bracket pair + one more,
      // resolving, released) can render identically as far as trailing
      // whitespace is concerned - only the character COUNT distinguishes
      // "nothing after it yet" from "already resolved".
      final bracketCloseAt = source.indexOf(']') + 1;
      var charsPushed = 0;
      var sawRawBracketStillAmbiguous = false;
      await _streamTypewriter(tester, source, (t, visible) {
        charsPushed++;
        if (charsPushed == bracketCloseAt && visible.contains('[docs]')) {
          sawRawBracketStillAmbiguous = true;
        }
      });
      expect(sawRawBracketStillAmbiguous, isFalse);
    },
  );

  testWidgets('! before [alt never flashes / never mangles into a stray ! '
      '(typewriter)', (tester) async {
    const source =
        'Great deal! Check ![alt text](https://x.y/a.png) image below. ';
    final frames = <String>[];
    await _streamTypewriter(tester, source, (t, visible) {
      frames.add(visible);
    });
    // The old bareOpenLink rewrite mishandled "![alt" mid-typing by
    // stripping only the '[' and leaving a stray '!alt...' behind.
    for (final f in frames) {
      expect(
        f.contains('!alt'),
        isFalse,
        reason: 'stray "!alt" leaked (missing "[" from an image): "$f"',
      );
    }
    expect(frames.last.trimRight(), 'Great deal! Check  image below.');
  });

  testWidgets('a digit run at line start never flashes before it resolves into '
      'ordinary text or a list marker (typewriter)', (tester) async {
    const source = 'Steps:\n\n12 apples were bought at the store today. ';
    // Track "is the digit run still bare (nothing after it yet)" by
    // stream position, not by pattern-matching the rendered text:
    // `gpt_markdown` collapses the blank line into a single block
    // boundary and trims trailing whitespace, so the "still bare" and
    // "just resolved" states can render as visually-identical strings -
    // only the character count distinguishes them.
    final digitRunEndsAt = source.indexOf('12') + '12'.length;
    var charsPushed = 0;
    var sawBareDigitRun = false;
    await _streamTypewriter(tester, source, (t, visible) {
      charsPushed++;
      if (charsPushed == digitRunEndsAt && visible.contains('12')) {
        sawBareDigitRun = true;
      }
    });
    expect(sawBareDigitRun, isFalse);
  });

  // --- B1F1 round 3 BLOCKER: table header hold when it's not the first ---
  // --- thing in the document -----------------------------------------------
  // The hold used to run only after `settledSplitOffset`, so a paragraph
  // (or list, or heading) before the table got the table row "settled"
  // right along with it, and the raw pipe-delimited row leaked through -
  // in every reveal mode, since none of them route around `mend`.
  for (final mode in ['smooth', 'typewriter', 'wordFade']) {
    Future<void> stream(
      WidgetTester tester,
      String source,
      void Function(WidgetTester, String) onFrame,
    ) {
      switch (mode) {
        case 'smooth':
          return _streamDefault(tester, source, onFrame);
        case 'typewriter':
          return _streamTypewriter(tester, source, onFrame);
        default:
          return _streamWordFade(tester, source, onFrame);
      }
    }

    testWidgets(
      'a header-only table row after a paragraph never renders raw ($mode)',
      (tester) async {
        const source =
            'Here:\n\n| Name | Age |\n|---|---|\n| Bob | 42 |\n\n'
            'Done with it. ';
        final sepCompleteAt = source.indexOf('|---|---|') + '|---|---|'.length;
        var charsPushed = 0;
        var sawRawPipeBeforeSeparator = false;
        await stream(tester, source, (t, visible) {
          charsPushed++;
          if (charsPushed < sepCompleteAt && visible.contains('|')) {
            sawRawPipeBeforeSeparator = true;
          }
        });
        expect(sawRawPipeBeforeSeparator, isFalse);
      },
    );

    testWidgets(
      'a partial separator after a paragraph never renders raw ($mode)',
      (tester) async {
        const source =
            'Some text first.\n\n| Name | Age |\n|--\nmore filler text. ';
        // The separator here never actually completes (it's cut off by
        // "more filler text" instead of a second `|---|`) - the header
        // must stay held for as long as the separator remains incomplete,
        // and once it's clear it never will complete, both the header and
        // the partial separator simply render as ordinary literal text
        // (still no CRASH, no stray raw mid-resolution artifact). What
        // matters here is that nothing shows a bare, dangling pipe row
        // while the separator is still actively ambiguous.
        final headerTypedAt =
            source.indexOf('| Name | Age |') + '| Name | Age |'.length;
        var charsPushed = 0;
        var sawRawHeaderAlone = false;
        await stream(tester, source, (t, visible) {
          charsPushed++;
          if (charsPushed == headerTypedAt + 1 && visible.contains('Name')) {
            // +1 char is exactly the newline right after the header, with
            // no separator typed yet at all - must still be held.
            sawRawHeaderAlone = true;
          }
        });
        expect(sawRawHeaderAlone, isFalse);
      },
    );
  }

  testWidgets('a header after a preceding list never renders raw (default)', (
    tester,
  ) async {
    const source = '- one\n- two\n\n| Name | Age |\n|---|---|\n\nDone. ';
    final sepCompleteAt = source.indexOf('|---|---|') + '|---|---|'.length;
    var charsPushed = 0;
    var sawRawPipeBeforeSeparator = false;
    await _streamDefault(tester, source, (t, visible) {
      charsPushed++;
      if (charsPushed < sepCompleteAt && visible.contains('|')) {
        sawRawPipeBeforeSeparator = true;
      }
    });
    expect(sawRawPipeBeforeSeparator, isFalse);
  });

  testWidgets(
    'a header after a preceding heading never renders raw (default)',
    (tester) async {
      const source = '## Section\n\n| Name | Age |\n|---|---|\n\nDone. ';
      final sepCompleteAt = source.indexOf('|---|---|') + '|---|---|'.length;
      var charsPushed = 0;
      var sawRawPipeBeforeSeparator = false;
      await _streamDefault(tester, source, (t, visible) {
        charsPushed++;
        if (charsPushed < sepCompleteAt && visible.contains('|')) {
          sawRawPipeBeforeSeparator = true;
        }
      });
      expect(sawRawPipeBeforeSeparator, isFalse);
    },
  );

  // --- B1F1 round 3, non-blocking item 1: don't hold inside code ----------
  testWidgets('vec![1 inside inline code is never mistaken for an image start '
      '(typewriter)', (tester) async {
    const source = 'Use `vec![1, 2, 3]` to build a vector quickly here. ';
    // Once the source has actually typed the '!' inside the inline code
    // span, the visible (code-styled) text must keep it - the old
    // (pre-guard) code truncated "vec![1" down to just "vec" the moment
    // "![1" appeared, since it read as an image-alt in progress, even
    // though it's plainly inside an open inline code span where `!`/`[`/
    // `]` are just literal characters.
    final bangTypedAt = source.indexOf('!') + 1;
    var charsPushed = 0;
    var sawStrayTruncation = false;
    await _streamTypewriter(tester, source, (t, visible) {
      charsPushed++;
      if (charsPushed >= bangTypedAt &&
          visible.contains('vec') &&
          !visible.contains('vec!')) {
        sawStrayTruncation = true;
      }
    });
    expect(sawStrayTruncation, isFalse);
  });

  testWidgets(
    'vec![1 inside a fenced code block is never mistaken for an image '
    'start (typewriter)',
    (tester) async {
      const source = 'Code:\n\n```rust\nlet v = vec![1, 2, 3];\n```\nDone. ';
      final frames = <String>[];
      await _streamTypewriter(tester, source, (t, visible) {
        frames.add(visible);
      });
      expect(frames.last.contains('vec![1, 2, 3]'), isTrue);
    },
  );

  // --- B1F1 round 3, non-blocking item 2: backtick flash inside a fence --
  testWidgets(
    'a trailing lone backtick on its own line inside an open fence never '
    'flashes (typewriter, 1-char chunks)',
    (tester) async {
      const source =
          'Code:\n\n```dart\nvoid main() {\n  print(1);\n}\n```\nAfter. ';
      final frames = <String>[];
      final calls = <String>[];
      await tester.pumpWidget(
        _host(
          StreamingTextMarkdown.typewriter(
            text: source,
            markdownEnabled: true,
            typingSpeed: frameInterval,
            codeBuilder: (context, name, code, closed) {
              calls.add(code);
              return Text('[$name:$closed]\n$code');
            },
          ),
        ),
      );
      for (var i = 0; i <= source.length; i++) {
        await tester.pump(frameInterval);
        frames.add(_visible(tester));
      }
      await pumpFrames(tester, 40);
      // The closing fence is typed one backtick at a time - at the instant
      // exactly one (or two) backticks of the closing ``` have landed, the
      // code content must not show a stray trailing backtick that doesn't
      // belong to the actual code.
      for (final code in calls) {
        expect(
          code.endsWith('`') && !code.endsWith('```'),
          isFalse,
          reason: 'a stray partial-closer backtick leaked into code: "$code"',
        );
      }
    },
  );
}
