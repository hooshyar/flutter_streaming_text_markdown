import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// W10/W11 regression coverage for LaTeX delegation.
///
/// On main, `latexEnabled` plus any detected LaTeX anywhere in the message
/// routed the *entire* render through `_buildLatexMarkdown`/
/// `_buildFormattedText` — a hand-rolled pipeline with no heading, list,
/// link or code-fence support at all, bypassing `GptMarkdown`/`codeBuilder`
/// completely. Both cases below fail on main for that reason.
void main() {
  testWidgets(
    'latexEnabled keeps headings and links rendering through GptMarkdown '
    'with useDollarSignsForLatex',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: '# Title\n\nSee \$x=1\$ and [docs](https://example.com).',
              markdownEnabled: true,
              latexEnabled: true,
              animationsEnabled: false,
            ),
          ),
        ),
      );
      await tester.pump();

      // On main this widget doesn't exist for LaTeX-bearing text at all.
      final markdown = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
      expect(markdown.useDollarSignsForLatex, isTrue);

      // Heading and link markup are consumed, not shown raw. gpt_markdown
      // paints most inline content straight onto a `RichText`/`BidiRichText`
      // rather than wrapping it in a `Text`, so these need `findRichText`.
      expect(find.textContaining('# Title', findRichText: true), findsNothing);
      expect(find.textContaining('[docs]', findRichText: true), findsNothing);
      expect(find.textContaining('docs', findRichText: true), findsOneWidget);
    },
  );

  testWidgets('shell \$VARS inside a code fence reach codeBuilder verbatim', (
    tester,
  ) async {
    String? capturedCode;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreamingText(
            // A genuine (paired, same-line) LaTeX expression elsewhere in
            // the message is what used to force the whole render onto the
            // custom LaTeX pipeline, taking codeBuilder down with it even
            // though the fence itself has only one, unpaired `$`.
            text:
                'The formula is \$x=1\$.\n\n'
                '```bash\necho \$PATH\n```\n',
            markdownEnabled: true,
            latexEnabled: true,
            animationsEnabled: false,
            codeBuilder: (context, name, code, closed) {
              capturedCode = code;
              return Text(code);
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(capturedCode, isNotNull);
    expect(capturedCode, contains(r'echo $PATH'));
  });
}
