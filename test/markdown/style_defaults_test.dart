import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// B2-S2: DESIGN.md's default markdown look is applied when the caller sets
/// nothing, and the caller's own [MarkdownRenderOptions] / `style` always
/// wins field by field.
void main() {
  group('default markdown style sheet', () {
    testWidgets('is applied when the caller supplies no styleSheet', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreamingText(
              revealMode: null,
              text: '`code`',
              markdownEnabled: true,
              animationsEnabled: false,
            ),
          ),
        ),
      );
      await tester.pump();

      final markdown = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
      final inlineCode = markdown.styleSheet?.inlineCode;
      expect(inlineCode, isNotNull);
      expect(inlineCode!.fontFamily, 'JetBrainsMono');
      expect(inlineCode.fontFamilyFallback, contains('monospace'));

      final table = markdown.styleSheet?.table;
      expect(table, isNotNull);
      expect(table!.borderColor, isNotNull);
      expect(table.headerBackground, isNotNull);
    });

    testWidgets(
      'the default body weight/height apply when style is null, but an '
      "ancestor's explicit fontSize is left alone",
      (tester) async {
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
        // `Scaffold`'s `Material` ancestor already sets an explicit
        // `fontSize` (14, from the theme's body text style) before this
        // widget ever runs - DESIGN.md's 16 is a *default*, not an
        // override, so it steps aside for that already-explicit ancestor
        // value (see `defaultMarkdownBodyStyle`'s doc for why: overriding
        // an already-explicit ancestor `fontSize` here fed a different
        // number into `gpt_markdown`'s own `blockGap()` than the rest of
        // the layout had settled on, which desynced this package's
        // trailing-fade mask for a few frames - the exact bug
        // `markdown_fade_invariant_stale_test.dart`'s "mixed" doc caught).
        // `fontWeight`/`height` aren't set by that ancestor, so DESIGN.md's
        // defaults for those still apply.
        expect(markdown.style?.fontSize, 14);
        expect(markdown.style?.fontWeight, FontWeight.w400);
      },
    );

    testWidgets(
      "the ancestor's colour carries through, and DESIGN.md's 16/25 apply "
      'when the ancestor sets no explicit fontSize/height at all',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DefaultTextStyle(
                style: const TextStyle(color: Color(0xFFFFFFFF)),
                child: const StreamingText(
                  revealMode: null,
                  text: 'Hello world',
                  markdownEnabled: true,
                  animationsEnabled: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final markdown = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
        expect(markdown.style?.color, const Color(0xFFFFFFFF));
        expect(markdown.style?.fontSize, 16);
        expect(markdown.style?.height, 25 / 16);
        expect(markdown.style?.fontWeight, FontWeight.w400);
      },
    );

    testWidgets(
      "DefaultTextStyle(color: white, fontSize: 13) keeps the colour white "
      "and honours the ancestor's own fontSize (base 09853c5's own "
      'behaviour, kept deliberately - see defaultMarkdownBodyStyle)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DefaultTextStyle(
                style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 13),
                child: const StreamingText(
                  revealMode: null,
                  text: 'Hello world',
                  markdownEnabled: true,
                  animationsEnabled: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final markdown = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
        expect(markdown.style?.color, const Color(0xFFFFFFFF));
        expect(markdown.style?.fontSize, 13);
      },
    );

    testWidgets("the caller's styleSheet field wins over the default", (
      tester,
    ) async {
      const callerInlineCode = InlineCodeStyle(fontFamily: 'CustomMono');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreamingText(
              revealMode: null,
              text: '`code`',
              markdownEnabled: true,
              animationsEnabled: false,
              markdownOptions: MarkdownRenderOptions(
                styleSheet: GptMarkdownStyleSheet(inlineCode: callerInlineCode),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final markdown = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
      expect(markdown.styleSheet?.inlineCode?.fontFamily, 'CustomMono');
      // A field the caller left unset on their own inlineCode style still
      // gets filled in from ours (merge is per field, not per object) - the
      // background colour keeps our DESIGN.md token.
      expect(markdown.styleSheet?.inlineCode?.backgroundColor, isNotNull);
      // A field on a different component the caller never touched at all
      // still gets our default.
      expect(markdown.styleSheet?.table?.headerBackground, isNotNull);
    });

    testWidgets("the caller's own style wins over the default body style", (
      tester,
    ) async {
      const callerStyle = TextStyle(fontSize: 30);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreamingText(
              revealMode: null,
              text: 'Hello world',
              markdownEnabled: true,
              animationsEnabled: false,
              markdownStyleSheet: callerStyle,
            ),
          ),
        ),
      );
      await tester.pump();

      final markdown = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
      expect(markdown.style?.fontSize, 30);
    });

    testWidgets("the caller's own tableBuilder wins over the default", (
      tester,
    ) async {
      var called = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingText(
              revealMode: null,
              text: '| A | B |\n|---|---|\n| 1 | 2 |',
              markdownEnabled: true,
              animationsEnabled: false,
              markdownOptions: MarkdownRenderOptions(
                tableBuilder: (context, rows, style, config) {
                  called = true;
                  return const SizedBox(key: Key('custom-table'));
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(called, isTrue);
      expect(find.byKey(const Key('custom-table')), findsOneWidget);
    });

    testWidgets(
      'a table still renders through gpt_markdown (fade-mask compatible), '
      'not a replacement builder, when the caller sets nothing',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StreamingText(
                revealMode: null,
                text: '| A | B |\n|---|---|\n| 1 | 2 |',
                markdownEnabled: true,
                animationsEnabled: false,
              ),
            ),
          ),
        );
        await tester.pump();

        final markdown = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
        // No default tableBuilder is installed - overriding it would drop
        // cells out of gpt_markdown's own MdWidget/fade-mask rendering path
        // (see LockedTableColumnWidth's doc comment).
        expect(markdown.tableBuilder, isNull);
        expect(find.byType(Table), findsOneWidget);
      },
    );

    testWidgets(
      "an ancestor GptMarkdownTheme's styleSheet is honoured over this "
      "package's own DESIGN.md defaults (but still loses to the caller's "
      'own styleSheet)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GptMarkdownTheme(
                gptThemeData: GptMarkdownThemeData(
                  brightness: Brightness.light,
                  styleSheet: const GptMarkdownStyleSheet(
                    link: LinkStyle(color: Color(0xFFFF0000)),
                    blockQuote: BlockQuoteStyle(barWidth: 9),
                  ),
                ),
                child: const StreamingText(
                  revealMode: null,
                  text: 'See [a link](https://x.y) now',
                  markdownEnabled: true,
                  animationsEnabled: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final markdown = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
        expect(markdown.styleSheet?.link?.color, const Color(0xFFFF0000));
        expect(markdown.styleSheet?.blockQuote?.barWidth, 9);
        // A field the ambient theme never set at all still gets this
        // package's own DESIGN.md default (the theme fills gaps the caller
        // left, our defaults fill gaps the theme left too).
        expect(markdown.styleSheet?.table?.headerBackground, isNotNull);
      },
    );

    testWidgets("the caller's own styleSheet field wins over an ambient "
        'GptMarkdownTheme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GptMarkdownTheme(
              gptThemeData: GptMarkdownThemeData(
                brightness: Brightness.light,
                styleSheet: const GptMarkdownStyleSheet(
                  link: LinkStyle(color: Color(0xFFFF0000)),
                ),
              ),
              child: const StreamingText(
                revealMode: null,
                text: 'See [a link](https://x.y) now',
                markdownEnabled: true,
                animationsEnabled: false,
                markdownOptions: MarkdownRenderOptions(
                  styleSheet: GptMarkdownStyleSheet(
                    link: LinkStyle(color: Color(0xFF00FF00)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final markdown = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
      expect(markdown.styleSheet?.link?.color, const Color(0xFF00FF00));
    });

    testWidgets(
      'with no ambient GptMarkdownTheme at all, this stays exactly the '
      "package's own DESIGN.md look (no synthetic theme-derived styling "
      'leaks in)',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StreamingText(
                revealMode: null,
                text: '`code`',
                markdownEnabled: true,
                animationsEnabled: false,
              ),
            ),
          ),
        );
        await tester.pump();

        final markdown = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
        expect(markdown.styleSheet?.inlineCode?.fontFamily, 'JetBrainsMono');
        expect(
          markdown.styleSheet?.inlineCode?.fontFamilyPackage,
          'gpt_markdown',
        );
      },
    );
  });

  group('table rendering', () {
    testWidgets('a table wider than the viewport scrolls with no overflow', (
      tester,
    ) async {
      final wideRow =
          '| ${List.generate(12, (i) => 'Column header number $i').join(' | ')} |';
      final separator = '|${List.generate(12, (_) => '---').join('|')}|';
      final dataRow =
          '| ${List.generate(12, (i) => 'value $i is quite long indeed').join(' | ')} |';
      final markdown = '$wideRow\n$separator\n$dataRow';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: StreamingText(
                revealMode: null,
                text: markdown,
                markdownEnabled: true,
                animationsEnabled: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('a column does not shrink as later, complete rows stream in '
        '(gpt_markdown default column sizing - see markdown_style_defaults.dart '
        "for why this slice doesn't add its own width lock)", (tester) async {
      Future<double> pumpTableAndMeasureColumnZero(String markdown) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamingText(
                revealMode: null,
                text: markdown,
                markdownEnabled: true,
                animationsEnabled: false,
              ),
            ),
          ),
        );
        await tester.pump();

        // Column 0's actual on-screen width, measured the same way for every
        // row - the width of the cell box that wraps column 0's first-row
        // text ("row1c0" is unique to the first data row across all three
        // pumps below, so it always resolves the same cell).
        final cellBox =
            find
                .ancestor(
                  of: find.text('row1c0'),
                  matching: find.byType(Padding),
                )
                .first;
        return tester.getSize(cellBox).width;
      }

      // First row: a short cell in column 0.
      final firstWidth = await pumpTableAndMeasureColumnZero(
        '| a | b |\n|---|---|\n| row1c0 | x |',
      );

      // A second, much wider cell streams into column 0 as row two arrives -
      // the column must grow, never regress on the next paint.
      final secondWidth = await pumpTableAndMeasureColumnZero(
        '| a | b |\n|---|---|\n| row1c0 | x |\n| a very much longer value | y |',
      );
      expect(secondWidth, greaterThanOrEqualTo(firstWidth));

      // A third row with a short cell arrives in the same column: the column
      // must stay locked at the widest value ever seen, not shrink back down.
      final thirdWidth = await pumpTableAndMeasureColumnZero(
        '| a | b |\n|---|---|\n| row1c0 | x |\n'
        '| a very much longer value | y |\n| tiny | z |',
      );
      expect(thirdWidth, greaterThanOrEqualTo(secondWidth));
    });
  });
}
