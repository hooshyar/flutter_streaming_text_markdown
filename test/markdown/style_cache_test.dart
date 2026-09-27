import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// W8 regression: a completed widget must restyle when its style changes.
///
/// On main, `_buildSimpleMarkdown` served `_completeMarkdownCache[text]` once
/// `_isComplete` was true, keyed on text alone — so a style change on an
/// already-complete widget kept rendering with the OLD style, and this fails
/// on main (finds the stale color instead of the new one). Styles are now
/// resolved fresh in `build` every time (the cache was deleted entirely), so
/// this passes.
void main() {
  testWidgets('a completed markdown widget restyles on a style change', (
    tester,
  ) async {
    const oldStyle = TextStyle(color: Colors.red);
    const newStyle = TextStyle(color: Colors.blue);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StreamingText(
            revealMode: null,
            text: 'Styled text',
            markdownEnabled: true,
            animationsEnabled: false,
            markdownStyleSheet: oldStyle,
          ),
        ),
      ),
    );
    await tester.pump();

    final before = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
    expect(before.style?.color, Colors.red);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StreamingText(
            revealMode: null,
            text: 'Styled text',
            markdownEnabled: true,
            animationsEnabled: false,
            markdownStyleSheet: newStyle,
          ),
        ),
      ),
    );
    await tester.pump();

    final after = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
    expect(after.style?.color, Colors.blue);
  });
}
