import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// W7 regression: auto-detected Arabic content must reach `GptMarkdown` as
/// RTL. On main this always passed `widget.textDirection ?? TextDirection.ltr`
/// — auto-detection was computed elsewhere for plain-text mode but never
/// consulted for the markdown render path, so this fails on main (finds
/// `TextDirection.ltr` instead of `TextDirection.rtl`).
void main() {
  testWidgets('Arabic markdown content is auto-detected as RTL', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StreamingText(
            revealMode: null,
            text: 'مرحبا بالعالم، هذا اختبار',
            markdownEnabled: true,
            animationsEnabled: false,
          ),
        ),
      ),
    );
    await tester.pump();

    final markdown = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
    expect(markdown.textDirection, TextDirection.rtl);
  });

  testWidgets('an explicit textDirection still wins over auto-detection', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StreamingText(
            revealMode: null,
            text: 'مرحبا بالعالم',
            markdownEnabled: true,
            animationsEnabled: false,
            textDirection: TextDirection.ltr,
          ),
        ),
      ),
    );
    await tester.pump();

    final markdown = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
    expect(markdown.textDirection, TextDirection.ltr);
  });

  testWidgets('plain English markdown content stays LTR', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StreamingText(
            revealMode: null,
            text: 'Hello world',
            markdownEnabled: true,
            animationsEnabled: false,
          ),
        ),
      ),
    );
    await tester.pump();

    final markdown = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
    expect(markdown.textDirection, TextDirection.ltr);
  });
}
