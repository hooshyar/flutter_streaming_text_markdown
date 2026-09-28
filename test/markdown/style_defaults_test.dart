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

    testWidgets('the default body text style is applied when style is null', (
      tester,
    ) async {
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
      expect(markdown.style?.fontSize, 16);
      expect(markdown.style?.fontWeight, FontWeight.w400);
    });

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
