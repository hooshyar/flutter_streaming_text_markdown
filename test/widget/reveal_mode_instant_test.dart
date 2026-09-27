// B1F1 round 6, item 2: `revealMode: RevealMode.instant` passed directly to
// `StreamingText` or the default `StreamingTextMarkdown` constructor typed
// one character per 50ms instead of showing everything immediately - only
// the `.instant()` factory worked, because it also happens to set
// `animationsEnabled: false`, and `_instantReveal`
// (lib/src/streaming/streaming_text.dart) never checked `revealMode` at
// all. Fixed by including `revealMode == RevealMode.instant` in
// `_instantReveal`'s condition.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

String _plainText(WidgetTester tester) {
  final parts = <String>[];
  for (final element in find.byWidgetPredicate((w) => w is Text).evaluate()) {
    final widget = element.widget as Text;
    parts.add(widget.data ?? widget.textSpan?.toPlainText() ?? '');
  }
  return parts.join();
}

void main() {
  testWidgets(
    'StreamingText(revealMode: RevealMode.instant) shows the full text '
    'text input after just 1 frame',
    (tester) async {
      const text = 'This entire sentence should appear immediately.';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: text,
              revealMode: RevealMode.instant,
              showCursor: false,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(_plainText(tester), text);
    },
  );

  testWidgets(
    'StreamingText(revealMode: RevealMode.instant) shows each stream chunk '
    'immediately, not typed at ~50ms/char',
    (tester) async {
      final controller = StreamController<String>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: '',
              stream: controller.stream,
              revealMode: RevealMode.instant,
              showCursor: false,
            ),
          ),
        ),
      );
      controller.add('First chunk arrives whole. ');
      await tester.pump(const Duration(milliseconds: 16));
      expect(_plainText(tester).trimRight(), 'First chunk arrives whole.');

      controller.add('Second chunk too.');
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        _plainText(tester).trimRight(),
        'First chunk arrives whole. Second chunk too.',
      );

      await controller.close();
      await tester.pump(const Duration(milliseconds: 16));
    },
  );

  testWidgets('StreamingTextMarkdown(revealMode: RevealMode.instant) (default '
      'constructor) shows the full text after just 1 frame', (tester) async {
    const text = 'This entire sentence should appear immediately.';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StreamingTextMarkdown(
            text: text,
            markdownEnabled: true,
            revealMode: RevealMode.instant,
            showCursor: false,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    final visible =
        find
            .byWidgetPredicate((w) => w is RichText)
            .evaluate()
            .map((e) => (e.widget as RichText).text.toPlainText())
            .join();
    expect(visible, text);
  });
}
