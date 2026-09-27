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
  for (final element in find.byType(RichText).evaluate()) {
    final text = (element.widget as RichText).text.toPlainText();
    if (text.trim().isNotEmpty) parts.add(text);
  }
  return parts.join().replaceAll('', '');
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

  for (final element in find.byType(RichText).evaluate()) {
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

  testWidgets('a ~~gone~ never becomes ~~gone~~~', (tester) async {
    const source = 'a ~~gone~ and more text follows to be sure. ';
    var sawTripleTilde = false;
    await _streamDefault(tester, source, (t, visible) {
      if (visible.contains('~~~')) sawTripleTilde = true;
    });
    expect(sawTripleTilde, isFalse);
  });
}
