import 'dart:async';

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
    'latexEnabled keeps headings and links rendering through GptMarkdown, '
    'converting \$...\$ itself instead of forwarding useDollarSignsForLatex',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreamingText(
              revealMode: null,
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
      // W11: gpt_markdown's own `useDollarSignsForLatex` rewrite is naive
      // and code-oblivious, so it is never forwarded - the package instead
      // rewrites `$...$` to `\(...\)` itself (code-aware, currency-safe)
      // before this reaches GptMarkdown, so the math still renders.
      expect(markdown.useDollarSignsForLatex, isFalse);
      expect(markdown.data, contains(r'\(x=1\)'));
      expect(markdown.data, isNot(contains(r'$x=1$')));

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
            revealMode: null,
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

  testWidgets(
    'multiple \$VARS in a fenced block reach codeBuilder verbatim, not '
    'paired into a bogus LaTeX span (W11)',
    (tester) async {
      String? capturedCode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingText(
              revealMode: null,
              text:
                  '```bash\n'
                  'export PATH=\$HOME/bin:\$PATH\n'
                  'echo "\$HOME and \$USER"\n'
                  '```',
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
      // On main, gpt_markdown's own naive `useDollarSignsForLatex` rewrite
      // runs before it knows what is code, non-greedily pairing the first
      // `$HOME` with the next `$PATH` into a bogus LaTeX span - mangling
      // `export PATH=$HOME/bin:$PATH` into `export PATH=\(HOME/bin:\)PATH`.
      expect(
        capturedCode,
        equals(
          'export PATH=\$HOME/bin:\$PATH\n'
          'echo "\$HOME and \$USER"',
        ),
      );
    },
  );

  testWidgets(
    'inline `\$HOME` code stays literal - even next to real math elsewhere '
    'in the same message - instead of pairing across the backtick (W11)',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreamingText(
              revealMode: null,
              // On main, gpt_markdown's naive rewrite scans the raw text
              // left to right and pairs the FIRST `$` it finds (the one
              // inside the backticks) with the NEXT one anywhere later (the
              // closing `$` of the real math expression), mangling both:
              // "$HOME` and real math $" becomes one bogus LaTeX span.
              text: 'Set `\$HOME` and real math \$x=1\$ here.',
              markdownEnabled: true,
              latexEnabled: true,
              animationsEnabled: false,
            ),
          ),
        ),
      );
      await tester.pump();

      final markdown = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
      expect(markdown.data, contains(r'`$HOME`'));
      expect(markdown.data, contains(r'\(x=1\)'));
      expect(markdown.data, isNot(contains(r'\(HOME')));
    },
  );

  testWidgets(
    'a real \$x^2\$ and \$\$\\frac{a}{b}\$\$ elsewhere in the same message '
    'still render as math (W11)',
    (tester) async {
      final capturedTex = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingText(
              revealMode: null,
              text:
                  'Inline \$x^2\$ and block:\n\n\$\$\\frac{a}{b}\$\$\n\n'
                  'done.',
              markdownEnabled: true,
              latexEnabled: true,
              animationsEnabled: false,
              latexBuilder: (context, tex, textStyle, inline) {
                capturedTex.add(tex);
                return Text(tex, style: textStyle);
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(capturedTex, containsAll(<String>['x^2', r'\frac{a}{b}']));
    },
  );

  testWidgets(
    'currency (\$5) does not stall a still-open stream when latexEnabled '
    '(W11 regression)',
    (tester) async {
      final controller = StreamController<String>();
      addTearDown(() {
        if (!controller.isClosed) controller.close();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingText(
              revealMode: null,
              text: '',
              stream: controller.stream,
              markdownEnabled: false,
              latexEnabled: true,
              typingSpeed: const Duration(milliseconds: 1),
            ),
          ),
        ),
      );

      String displayed() {
        final texts = tester.widgetList<Text>(find.byType(Text));
        return texts
            .map(
              (t) =>
                  t.textSpan?.toPlainText(includePlaceholders: false) ??
                  t.data ??
                  '',
            )
            .join();
      }

      // `$5` is NOT the tail of the source here (more text follows it), so
      // - unlike the engine's normal one-grapheme trailing withhold while
      // open - there is nothing legitimate stopping the reveal from
      // reaching well past it. On main, an unclosed `$` (currency,
      // misdetected as an opening LaTeX delimiter with no matching close
      // yet) holds the reveal frozen right before it forever, waiting for a
      // closing `$` that will never come.
      controller.add('It costs \$5 per month. Then more text follows.');
      await tester.pump();
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 5));
      }

      expect(displayed(), contains('It costs \$5 per month.'));

      await controller.close();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 5));
      }
      expect(displayed(), 'It costs \$5 per month. Then more text follows.');
    },
  );
}
