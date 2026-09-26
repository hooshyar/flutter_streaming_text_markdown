// Acceptance criterion 9 / DESIGN.md 4.2: `showCursor` renders an 8x8
// pulsing dot caret while revealing, hidden once complete, in both plain and
// markdown mode - and the caret sentinel never leaks into the final markdown
// text, so `final text == source` still holds.
//
// Today (main @ 38bc831) `showCursor` is accepted but renders nothing - see
// DESIGN.md: "Today `showCursor` exists but renders nothing; that is a bug,
// not a design choice." These tests fail there (no `StreamingCaret` ever
// appears) and pass after the fix.
//
// These tests never call `pumpAndSettle` while the caret/stream is open -
// only bounded `pump(Duration)` calls.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_streaming_text_markdown/src/render/streaming_caret.dart';
import 'package:flutter_streaming_text_markdown/src/streaming/streaming_text.dart';

String _plainText(WidgetTester tester) {
  final richTexts = tester.widgetList<RichText>(find.byType(RichText));
  return richTexts
      .map((t) => t.text.toPlainText(includePlaceholders: false))
      .join();
}

void main() {
  group('caret', () {
    testWidgets('present mid-reveal in plain-text mode', (tester) async {
      const source = 'the quick brown fox jumps over the lazy dog';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: source,
              markdownEnabled: false,
              typingSpeed: Duration(seconds: 5),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(StreamingCaret), findsOneWidget);

      await tester.tap(find.byType(StreamingText));
      await tester.pump();
      await tester.pump();

      expect(find.byType(StreamingCaret), findsNothing);
    });

    testWidgets(
        'present mid-reveal in markdown mode, gone after completion, '
        'final text == source', (tester) async {
      // No markdown syntax (bold/italic/etc. render without their markers,
      // so a source containing them wouldn't equal the rendered plain text)
      // - just prose, to isolate the caret-sentinel-leak assertion.
      const source = 'plain markdown text, no code fences, no syntax';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: source,
              markdownEnabled: true,
              typingSpeed: Duration(milliseconds: 200),
            ),
          ),
        ),
      );
      // Reveal a little content first so the block has non-zero size to tap
      // (an empty markdown document lays out at zero height).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(StreamingCaret), findsOneWidget);

      // Tap the caret itself, not the widget's (much larger, mostly-empty)
      // bounding box: the markdown block is start-aligned and doesn't fill
      // its Scaffold-sized ancestor, so a center tap on `StreamingText`
      // would miss the actual rendered content.
      await tester.tap(find.byType(StreamingCaret));
      await tester.pump();
      await tester.pump();

      expect(find.byType(StreamingCaret), findsNothing);
      expect(_plainText(tester), source);
    });

    testWidgets('hidden entirely when showCursor is false', (tester) async {
      const source = 'no caret here please';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: source,
              markdownEnabled: false,
              showCursor: false,
              typingSpeed: Duration(seconds: 5),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(StreamingCaret), findsNothing);
    });
  });
}
