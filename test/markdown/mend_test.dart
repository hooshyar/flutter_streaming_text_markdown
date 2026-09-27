import 'package:flutter_streaming_text_markdown/src/render/mend.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit coverage for `mend`, the render-only tail-mending transform that
/// replaces `withholdOpenFence` (Phase B1-S1). `mend` is a pure function new
/// in this slice, so "fails on the phase base (627e72d)" is: the function
/// doesn't exist there at all - importing this path doesn't compile.
void main() {
  group('mend: isComplete is always the identity (AC1)', () {
    // A wide corpus of complete documents, including every probe12 case
    // (scratchpad/stm/probe12/test/probe_partial_md_test.dart) plus the
    // extra shapes acceptance criterion 1 calls out. `isComplete: true`
    // must return every one of them byte-for-byte unchanged, regardless of
    // what markdown-ish content they contain.
    const corpus = <String, String>{
      // probe12 cases, verbatim.
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
      // Extra AC1 shapes.
      'setext_dash': 'Title\n--\n\nBody',
      'setext_equals': 'Title\n==\n\nBody',
      'bold_italic_closed': 'Mixed ***strong italic*** done',
      'underscore_bold_closed': 'This is __bold__ text',
      'intraword_underscore': 'snake_case_name stays literal',
      'star_list_marker': '* first\n* second\n* third',
      'escaped_star_mid': r'5\*3=15, not math',
      'crlf_doc': 'Line one\r\nLine two\r\n\r\nLine three',
      'currency_range': r'Prices: $5-10, $5bn, and $5–10 too.',
      'currency_bold': r'**$20** off today',
      'plain_paragraph': 'Just a normal finished paragraph.',
      'closed_fence': 'Code:\n\n```dart\nvoid main() {}\n```\nDone.',
      'closed_math_block': r'Formula: $$\frac{a}{b}$$ done.',
    };

    for (final entry in corpus.entries) {
      test('identity for ${entry.key}', () {
        expect(mend(entry.value, isComplete: true), entry.value);
      });
    }

    test('corpus has at least 30 rows', () {
      expect(corpus.length, greaterThanOrEqualTo(30));
    });

    test('is the identity for empty text too', () {
      expect(mend('', isComplete: true), '');
    });
  });

  group('mend: close unterminated markers with content after them', () {
    test('closes an unterminated **bold', () {
      expect(
        mend('This is **very imp', isComplete: false),
        'This is **very imp**',
      );
    });

    test('closes an unterminated *italic', () {
      expect(mend('This is *emph', isComplete: false), 'This is *emph*');
    });

    test('closes an unterminated ***bold-italic', () {
      expect(mend('Mixed ***str', isComplete: false), 'Mixed ***str***');
    });

    test('closes an unterminated __bold (underscore)', () {
      expect(
        mend('This is __very imp', isComplete: false),
        'This is __very imp__',
      );
    });

    test('closes an unterminated ~~strike', () {
      expect(mend('Old ~~price', isComplete: false), 'Old ~~price~~');
    });

    test('closes an unterminated `inline code', () {
      expect(mend('Call `fooBar(', isComplete: false), 'Call `fooBar(`');
    });

    test('does not touch an escaped \\* (not an opener)', () {
      expect(mend(r'Price 5\*', isComplete: false), r'Price 5\*');
    });

    test('skips a leading "* " list marker instead of closing it', () {
      expect(mend('* first item text', isComplete: false), '* first item text');
    });

    test('does not treat an intraword _ as emphasis', () {
      expect(
        mend('snake_case_name still typing', isComplete: false),
        'snake_case_name still typing',
      );
    });
  });

  group('mend: hold a lone trailing marker with nothing after it', () {
    test('holds a lone trailing **', () {
      expect(mend('This is **', isComplete: false), 'This is ');
    });

    test('holds a lone trailing *', () {
      expect(mend('This is *', isComplete: false), 'This is ');
    });

    test('holds a lone trailing ~', () {
      // A single '~' never opens anything on its own (strike is '~~'), so
      // there is nothing to close or hold - it is just literal text.
      expect(mend('This is ~', isComplete: false), 'This is ~');
    });

    test('holds a lone trailing backtick', () {
      expect(mend('This is `', isComplete: false), 'This is ');
    });
  });

  group('mend: marker-only lines are held back (probe12)', () {
    test('list_marker_only', () {
      expect(mend('Steps:\n\n1.', isComplete: false), 'Steps:\n\n');
    });

    test('bullet_marker_only', () {
      expect(mend('Steps:\n\n-', isComplete: false), 'Steps:\n\n');
    });

    test('nested_list_partial holds only the dangling nested marker', () {
      expect(mend('- a\n  - b\n    -', isComplete: false), '- a\n  - b\n');
    });

    test('heading_marker_only', () {
      expect(mend('Intro\n\n##', isComplete: false), 'Intro\n\n');
    });

    test('heading_partial is NOT held (has content already)', () {
      expect(mend('Intro\n\n## Setu', isComplete: false), 'Intro\n\n## Setu');
    });

    test('blockquote_marker', () {
      expect(mend('Quote:\n\n>', isComplete: false), 'Quote:\n\n');
    });

    test('hr_partial (setext/hr dash run)', () {
      expect(mend('Above\n\n--', isComplete: false), 'Above\n\n');
    });
  });

  group('mend: fences (probe12 + fence semantics)', () {
    test('an open fence with a committed opener line passes through', () {
      const text = 'Code:\n\n```dart\nvoid main() {';
      expect(mend(text, isComplete: false), text);
    });

    test('a bare 1-2 backtick run with no newline yet is held back', () {
      expect(mend('Code:\n\n``', isComplete: false), 'Code:\n\n');
    });

    test('a single trailing backtick with no newline yet is held back', () {
      expect(mend('Code:\n\n`', isComplete: false), 'Code:\n\n');
    });

    test('an in-progress fence opener with a partial language is held', () {
      expect(mend('Code:\n\n```da', isComplete: false), 'Code:\n\n');
    });

    test('balanced fences are the identity mid-stream', () {
      const text = 'Here:\n```dart\nfinal x = 1;\n```\nDone';
      expect(mend(text, isComplete: false), text);
    });
  });

  group(
    'mend: table header held until its separator completes (non-blocking)',
    () {
      test('table_header_only has no separator yet - held entirely', () {
        expect(mend('| Name | Age |', isComplete: false), '');
      });

      test(
        'table_sep_partial - a still-typing separator holds the header too',
        () {
          expect(mend('| Name | Age |\n|---', isComplete: false), '');
        },
      );

      test('a header committed with nothing after it yet is held', () {
        expect(mend('| Name | Age |\n', isComplete: false), '');
      });

      test('a completed separator lets the header through', () {
        const text = '| Name | Age |\n|---|---|\n';
        expect(mend(text, isComplete: false), text);
      });

      test(
        'table_row_partial (separator already complete) is untouched here',
        () {
          const text = '| Name | Age |\n|---|---|\n| Bob | 4';
          expect(mend(text, isComplete: false), text);
        },
      );
    },
  );

  group('mend: links and images are rewritten/held (probe12)', () {
    test('link_text_open drops the bracket', () {
      expect(mend('See [the docs', isComplete: false), 'See the docs');
    });

    test('link_url_open collapses to just the link text', () {
      expect(
        mend('See [the docs](https://exa', isComplete: false),
        'See the docs',
      );
    });

    test('image_open is dropped entirely', () {
      expect(mend('Pic ![alt](https://x.y/a.pn', isComplete: false), 'Pic ');
    });

    test('html_open holds the unclosed tag', () {
      expect(mend('Line<br', isComplete: false), 'Line');
    });
  });

  group('mend: math (AC4 - see also latex_delegation_test.dart for S3)', () {
    test(r'an open $$ block becomes a math-pending fence with no literal $$ '
        'when latex is enabled', () {
      final result = mend(
        r'Formula:$$\frac{a}{',
        isComplete: false,
        latexEnabled: true,
      );
      expect(result, 'Formula:```math-pending\n\\frac{a}{');
      expect(result.contains(r'$$'), isFalse);
    });

    test(r'an open inline $x becomes inline code without the $ when latex is '
        'enabled', () {
      final result = mend(
        r'Energy $E = mc^',
        isComplete: false,
        latexEnabled: true,
      );
      expect(result, 'Energy `E = mc^`');
      expect(result.contains(r'$'), isFalse);
    });

    test('currency-shaped \$ is left untouched', () {
      expect(
        mend(r'That costs $5 today', isComplete: false, latexEnabled: true),
        r'That costs $5 today',
      );
    });

    // B1F1 bug #2: latexEnabled defaults to false, and mend must not rewrite
    // an open `$var` at all in that case - the `$` must survive, matching
    // base 627e72d (which showed a literal `$count` all along) instead of
    // swallowing it into inline code.
    test(r'latexEnabled defaults to false: an open $x is left untouched', () {
      final result = mend(r'Energy $E = mc^', isComplete: false);
      expect(result, r'Energy $E = mc^');
    });

    test(r'latexEnabled: false leaves an open $$ block untouched too', () {
      final result = mend(
        r'Formula:$$\frac{a}{',
        isComplete: false,
        latexEnabled: false,
      );
      expect(result, r'Formula:$$\frac{a}{');
    });
  });
}
