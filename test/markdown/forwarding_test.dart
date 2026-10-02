import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'package:flutter_streaming_text_markdown/src/render/markdown_options.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// TASK-015 forwarding regression coverage. Each of these fails on main
/// (38bc831): `StreamingText` had no `markdownOptions` field at all (the
/// styleSheet/components cases don't compile) and `linkBuilder` was forwarded
/// to `GptMarkdown.linkBuilder` (the deprecated Widget-returning hook), not
/// adapted to `inlineLinkBuilder`, so the inline builder below never fired.
void main() {
  Future<GptMarkdown> pumpAndFindMarkdown(
    WidgetTester tester,
    StreamingText widget,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
    await tester.pump();
    return tester.widget<GptMarkdown>(find.byType(GptMarkdown));
  }

  testWidgets('styleSheet is forwarded to GptMarkdown', (tester) async {
    const sheet = GptMarkdownStyleSheet(
      blockQuote: BlockQuoteStyle(barWidth: 6),
    );

    final markdown = await pumpAndFindMarkdown(
      tester,
      const StreamingText(
        revealMode: null,
        text: 'Hello world',
        animationsEnabled: false,
        markdownOptions: MarkdownRenderOptions(styleSheet: sheet),
      ),
    );

    expect(markdown.styleSheet, same(sheet));
  });

  testWidgets('GptMarkdown.components is null by default', (tester) async {
    final markdown = await pumpAndFindMarkdown(
      tester,
      const StreamingText(
        revealMode: null,
        text: 'Hello world',
        animationsEnabled: false,
      ),
    );

    // ignore: deprecated_member_use
    expect(markdown.components, isNull);
    // ignore: deprecated_member_use
    expect(markdown.inlineComponents, isNull);
  });

  testWidgets('linkBuilder receives the URL via the inline builder', (
    tester,
  ) async {
    String? capturedUrl;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreamingText(
            revealMode: null,
            text: '[docs](https://example.com/a)',
            markdownEnabled: true,
            animationsEnabled: false,
            linkBuilder: (context, text, url, style) {
              capturedUrl = url;
              return Text(text.toPlainText(), style: style);
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(capturedUrl, 'https://example.com/a');
  });
}
