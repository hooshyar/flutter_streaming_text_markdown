// Acceptance criterion 2: for every probe12 partial case
// (scratchpad/stm/probe12/test/probe_partial_md_test.dart), the rendered
// plain text mid-stream must never contain a raw, half-typed markdown
// artifact: `**`, a lone backtick, `$$`, `|---`, `](`, or an empty bullet,
// heading or quote marker.
//
// Renders each case through `StreamingMarkdownView` directly with
// `isComplete: false` - the exact "mid-stream, more text may still arrive"
// state `mend` (lib/src/render/mend.dart) exists to handle - rather than via
// `StreamingText`'s own internal typing timer, which (with
// `animationsEnabled: false`, as the probe used) reveals everything at once
// and never actually observes a mid-stream frame.

import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/src/render/markdown_renderer.dart';
import 'package:flutter_test/flutter_test.dart';

String _visiblePlainText(WidgetTester tester) {
  final parts = <String>[];
  for (final element in find.byType(RichText).evaluate()) {
    final span = (element.widget as RichText).text.toPlainText();
    if (span.trim().isNotEmpty) parts.add(span);
  }
  return parts.join(' ⏎ ');
}

// The 26 probe12 cases, verbatim.
const _probe12Cases = <String, String>{
  'bold_open': 'This is **very imp',
  'italic_open': 'This is *emph',
  'bold_italic_open': 'Mixed ***str',
  'strike_open': 'Old ~~price',
  'inline_code_open': 'Call `fooBar(',
  'link_text_open': 'See [the docs',
  'link_url_open': 'See [the docs](https://exa',
  'image_open': 'Pic ![alt](https://x.y/a.pn',
  'table_header_only': '| Name | Age |',
  'table_sep_partial': '| Name | Age |\n|---',
  'table_row_partial': '| Name | Age |\n|---|---|\n| Bob | 4',
  'list_marker_only': 'Steps:\n\n1.',
  'bullet_marker_only': 'Steps:\n\n-',
  'nested_list_partial': '- a\n  - b\n    -',
  'heading_marker_only': 'Intro\n\n##',
  'heading_partial': 'Intro\n\n## Setu',
  'fence_open': 'Code:\n\n```dart\nvoid main() {',
  'fence_lang_partial': 'Code:\n\n``',
  'latex_inline_open': r'Energy $E = mc^',
  'latex_block_open': 'Formula:\n\n\$\$\\frac{a}{',
  'latex_paren_open': r'Energy \(E = mc^',
  'html_open': 'Line<br',
  'html_tag_open': 'Text <span style="color:red">red',
  'blockquote_marker': 'Quote:\n\n>',
  'hr_partial': 'Above\n\n--',
  'escaped_star': r'Price 5\*',
};

final RegExp _emptyBulletOrHeadingOrQuote = RegExp(
  r'(^|\n)[ \t]*(?:[-*+]|\d+\.|#{1,6}|>)[ \t]*($|\n)',
);

// B1F1 bug #2: with latexEnabled: false (the default), mend no longer
// rewrites an open `$`/`$$` at all - so `latex_inline_open` and
// `latex_block_open` legitimately keep their literal `$`/`$$` in that mode
// now (see mend_test.dart's dedicated "latexEnabled defaults to false"
// tests for the exact expected text). Skip just those two keys' `$$`
// assertion when latex is off; every other artifact check still applies.
const _mathKeys = {'latex_inline_open', 'latex_block_open'};

void main() {
  for (final latex in [false, true]) {
    for (final entry in _probe12Cases.entries) {
      testWidgets('mid-stream ${entry.key} (latex=$latex) has no raw markdown '
          'artifact', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StreamingMarkdownView(
                  text: entry.value,
                  isComplete: false,
                  latexEnabled: latex,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);

        final visible = _visiblePlainText(tester);
        expect(
          visible.contains('**'),
          isFalse,
          reason: 'raw ** leaked for ${entry.key}: "$visible"',
        );
        expect(
          visible.contains('`'),
          isFalse,
          reason: 'a lone backtick leaked for ${entry.key}: "$visible"',
        );
        final skipDollarCheck = !latex && _mathKeys.contains(entry.key);
        if (!skipDollarCheck) {
          expect(
            visible.contains(r'$$'),
            isFalse,
            reason: 'raw \$\$ leaked for ${entry.key}: "$visible"',
          );
        }
        expect(
          visible.contains('|---'),
          isFalse,
          reason: 'raw |--- leaked for ${entry.key}: "$visible"',
        );
        expect(
          visible.contains(']('),
          isFalse,
          reason: 'raw ]( leaked for ${entry.key}: "$visible"',
        );
        expect(
          _emptyBulletOrHeadingOrQuote.hasMatch(visible),
          isFalse,
          reason:
              'an empty bullet/heading/quote marker leaked for '
              '${entry.key}: "$visible"',
        );
      });
    }
  }
}
