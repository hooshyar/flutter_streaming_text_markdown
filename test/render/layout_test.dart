// Acceptance criterion 7 (W21) / DESIGN.md: markdown content inside an
// unbounded-width ancestor (a bare `Row`) must not throw, and alignment must
// honour the caller's `TextAlign` (directionally) instead of a hard-coded
// left/right guess.
//
// Today (main @ 38bc831) the markdown branch wraps content in
// `Container(width: double.infinity, ...)`, which asserts/throws when the
// incoming width constraint is unbounded (e.g. inside a `Row` with no
// `Expanded`/`Flexible`). This test fails there and passes after the
// `LayoutBuilder`-based fix.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'package:flutter_streaming_text_markdown/src/streaming/streaming_text.dart';

void main() {
  group('layout', () {
    testWidgets('markdown inside a Row does not throw', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                StreamingText(
                  text: '**hello** world',
                  markdownEnabled: true,
                  showCursor: false,
                  animationsEnabled: false,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Arabic honours TextAlign.center', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: 'مرحبا بكم في العالم',
              markdownEnabled: true,
              showCursor: false,
              animationsEnabled: false,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);

      // The alignment reaches gpt_markdown's own `GptMarkdown.textAlign`.
      final gptMarkdown = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
      expect(gptMarkdown.textAlign, TextAlign.center);
    });
  });
}
