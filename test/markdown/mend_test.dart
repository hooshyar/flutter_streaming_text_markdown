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

    // B1F1 round 2: `__` is no longer tracked/closed at all - gpt_markdown
    // 1.3.0 doesn't actually render `__`/`_` emphasis, it always shows the
    // underscores literally, so "closing" an unterminated `__` only ever
    // invented extra raw underscores that were never going to be styled
    // (e.g. 'Hello __bold_' used to become 'Hello __bold___'). This
    // replaces the old "closes an unterminated __bold" expectation.
    test('never closes an unterminated __bold (underscore) - left literal', () {
      expect(
        mend('This is __very imp', isComplete: false),
        'This is __very imp',
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

  // B1F1 round 2 BLOCKER: these three mend()-level asserts were missing
  // from round 1's suite - the widget-level tests in
  // inline_marker_streaming_test.dart happened to pass on the buggy base
  // (b22e28d) too, since gpt_markdown's own rendering masked the exact
  // string mend() produced. Calling mend() directly pins the precise
  // output and genuinely fails on b22e28d (verified in a scratch worktree
  // - see this file's own test names for what each one guards).
  group('mend: B1F1 round 2 direct regression asserts', () {
    test(
      'Hello **bold* closes the still-open ** instead of leaving it raw',
      () {
        // On b22e28d this returns 'Hello **bold' (the trailing lone '*' is
        // trimmed, but the still-open '**' bold span's closer is dropped
        // instead of appended) - a raw, unclosed '**' then leaks through
        // to gpt_markdown.
        expect(mend('Hello **bold*', isComplete: false), 'Hello **bold**');
      },
    );

    test('a ~~gone~ closes to ~~gone~~, never ~~gone~~~', () {
      // On b22e28d this returns 'a ~~gone~~~' (the lone trailing '~' isn't
      // recognized as ambiguous at all, so it survives literally AND the
      // still-open '~~' closer gets appended after it).
      expect(mend('a ~~gone~', isComplete: false), 'a ~~gone~~');
    });

    test('_private in prose never gets an invented trailing _', () {
      // On b22e28d, a lone `_` preceded by non-word/followed by word chars
      // toggles `underEmOpen` with no regard for whether it will ever
      // close, so this returns
      // 'Use snake_case and _private names in this module always. _'
      // (note the invented trailing '_'). mend() must never track a single
      // `_` as an emphasis delimiter at all.
      const source =
          'Use snake_case and _private names in this module always. ';
      final result = mend(source, isComplete: false);
      expect(result, source);
      expect(result.endsWith('_'), isFalse);
    });
  });

  group('mend: hold a lone trailing marker with nothing after it', () {
    test('holds a lone trailing **', () {
      expect(mend('This is **', isComplete: false), 'This is ');
    });

    test('holds a lone trailing *', () {
      expect(mend('This is *', isComplete: false), 'This is ');
    });

    // B1F1 round 2: a lone trailing '~' is now always held, even with no
    // strike span open at all - one more '~' arriving would turn it into a
    // strike-through delimiter, so it's ambiguous every frame it's the very
    // last character. This replaces the old "it's just literal text"
    // expectation (that was itself the one-frame-flash bug the round-2
    // report called out).
    test('holds a lone trailing ~ even with no strike open', () {
      expect(mend('This is ~', isComplete: false), 'This is ');
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

  // B1F1 round 6, item 1 (regression vs base 627e72d): a thematic-break
  // line (`***`, `---`, `___`, `* * *`) is a structural horizontal rule,
  // never emphasis. `mend` used to scan `***` as an unterminated
  // bold-italic opener and append a synthetic closing `***` at the very
  // end of the tail, corrupting unrelated text much later in the stream
  // (`mend('A.\n\n***\n\nFinal', isComplete:false)` returned
  // '...Final***'). `---`/`___`/`* * *` never actually toggled anything in
  // the old scanner either (`-`/`_` single chars aren't tracked, and
  // spaced-out `* * *` never forms a `***` run) - covered here anyway so a
  // future change to how those characters are scanned doesn't reintroduce
  // this class of bug silently.
  group(
    'mend: a thematic break line is never treated as an emphasis opener',
    () {
      test('*** does not get a synthetic closing *** appended', () {
        expect(
          mend('A.\n\n***\n\nFinal', isComplete: false),
          'A.\n\n***\n\nFinal',
        );
      });

      test('--- is untouched', () {
        expect(
          mend('A.\n\n---\n\nFinal', isComplete: false),
          'A.\n\n---\n\nFinal',
        );
      });

      test('___ is untouched', () {
        expect(
          mend('A.\n\n___\n\nFinal', isComplete: false),
          'A.\n\n___\n\nFinal',
        );
      });

      test('spaced-out * * * is untouched', () {
        expect(
          mend('A.\n\n* * *\n\nFinal', isComplete: false),
          'A.\n\n* * *\n\nFinal',
        );
      });

      test('an in-progress *** (still the last line) is left literal', () {
        expect(mend('A.\n\n***', isComplete: false), 'A.\n\n***');
      });

      test('setext "--" (heading underline) hold still works', () {
        expect(mend('Title\n--', isComplete: false), 'Title\n');
      });

      test(
        'a genuine inline ***bold-italic*** (not its own line) still closes',
        () {
          expect(mend('Mixed ***str', isComplete: false), 'Mixed ***str***');
        },
      );
    },
  );

  // B1F1 round 4 BLOCKER-FEEDING: mend held a bare '-' but passed a
  // trailing '- ' (marker plus a space, no content yet) straight through.
  // gpt_markdown then transiently rendered the whole list as one
  // '@\n@\n\n-' paragraph, triggering a fade flash. Every marker + trailing
  // whitespace-only combination must be held exactly like the bare marker.
  group('mend: marker + trailing space (no content yet) is held too', () {
    test('bulleted "- " is held', () {
      expect(mend('Steps:\n\n- ', isComplete: false), 'Steps:\n\n');
    });

    test('bulleted "* " is held', () {
      expect(mend('Steps:\n\n* ', isComplete: false), 'Steps:\n\n');
    });

    test('bulleted "+ " is held', () {
      expect(mend('Steps:\n\n+ ', isComplete: false), 'Steps:\n\n');
    });

    test('numbered "1. " is held', () {
      expect(mend('Steps:\n\n1. ', isComplete: false), 'Steps:\n\n');
    });

    test('numbered "1) " is held', () {
      expect(mend('Steps:\n\n1) ', isComplete: false), 'Steps:\n\n');
    });

    test('blockquote "> " is held', () {
      expect(mend('Quote:\n\n> ', isComplete: false), 'Quote:\n\n');
    });

    test('heading "## " is held', () {
      expect(mend('Intro\n\n## ', isComplete: false), 'Intro\n\n');
    });

    test('nested "  - " keeps the outer item, holds the nested marker', () {
      expect(mend('- a\n  - ', isComplete: false), '- a\n');
    });

    test('a bulleted item WITH real content after the space is not held', () {
      expect(
        mend('Steps:\n\n- do the thing', isComplete: false),
        'Steps:\n\n- do the thing',
      );
    });

    test('a numbered item with real content after the space is not held', () {
      expect(
        mend('Steps:\n\n1. do the thing', isComplete: false),
        'Steps:\n\n1. do the thing',
      );
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

  group('mend: table header held until its separator completes', () {
    test('table_header_only has no separator yet - held entirely', () {
      expect(mend('| Name | Age |', isComplete: false), '');
    });

    // B1F1 round 3 BLOCKER: the hold only ran on the tail AFTER
    // `settledSplitOffset`, which - unlike `_holdImageOrLinkStart` -
    // meant a table that isn't the very first thing in the document
    // leaked raw. `gpt_markdown`'s own settled/unsettled split has no
    // notion of "might still become a table", so a paragraph (or a list,
    // or a heading) before it got `settled` right along with the table
    // row that followed it.
    test('a header after a preceding paragraph is held, not just a header '
        'that starts the document', () {
      expect(mend('Here:\n\n| Name |', isComplete: false), 'Here:\n\n');
    });

    test('a header after a preceding paragraph, no closing pipe', () {
      expect(mend('Here:\n\n| Name | Age', isComplete: false), 'Here:\n\n');
    });

    test('a partial separator after a preceding paragraph is held too', () {
      expect(
        mend('Here:\n\n| Name | Age |\n|---', isComplete: false),
        'Here:\n\n',
      );
    });

    test('a header after a preceding list is held', () {
      expect(
        mend('- one\n- two\n\n| Name | Age |', isComplete: false),
        '- one\n- two\n\n',
      );
    });

    test('a header after a preceding heading is held', () {
      expect(
        mend('## Section\n\n| Name | Age |', isComplete: false),
        '## Section\n\n',
      );
    });

    test('a completed separator after a preceding paragraph lets the table '
        'through', () {
      const text = 'Here:\n\n| Name | Age |\n|---|---|\n';
      expect(mend(text, isComplete: false), text);
    });

    // B1F1 round 4, non-blocking item 2: a partial separator with no
    // newline yet used to leak raw once it happened to already satisfy the
    // minimal separator grammar (e.g. "|---|-" technically parses as one
    // pipe-dash-pipe-dash sequence) - it must stay held until an actual
    // newline lands, since the typist may still be adding columns.
    test('"|---|-" (no newline yet) is still held, not "complete"', () {
      expect(mend('| Name | Age |\n|---|-', isComplete: false), '');
    });

    test('"|---|---" (no newline yet) is still held too', () {
      expect(mend('| Name | Age |\n|---|---', isComplete: false), '');
    });

    test('once the newline lands, the same separator renders', () {
      const text = '| Name | Age |\n|---|---|\n';
      expect(mend(text, isComplete: false), text);
    });

    // B1F1 round 2: the row-like check used to require a trailing `|`
    // too, so a header missing its closing pipe leaked through raw. Any
    // line starting with `|` (after optional indentation) must hold now.
    test('a header with no closing pipe is held just the same', () {
      expect(mend('| Name | Age', isComplete: false), '');
    });

    test('a header partial with no closing pipe is held (typewriter)', () {
      expect(mend('| Nam', isComplete: false), '');
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
  });

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

  // B1F1 round 2, item 3: typewriter one-frame flashes - hold each of these
  // until the construct resolves, instead of showing a half-typed
  // construct for exactly one frame (or, worse, the wrong construct).
  group('mend: B1F1 round 2 typewriter-flash holds', () {
    test('a lone trailing ~ is held even with no strike span open at all', () {
      // One more '~' arriving would turn this into a strike-through
      // delimiter, an entirely different construct - held every frame
      // it is the very last character, not just once a strike is open.
      expect(mend('price ~5 or so', isComplete: false), 'price ~5 or so');
      expect(mend('price ~', isComplete: false), 'price ');
    });

    test('[text] with no ( yet is held entirely', () {
      expect(mend('See [docs]', isComplete: false), 'See ');
    });

    test('[text](url) still works once the paren has started', () {
      expect(mend('See [docs](h', isComplete: false), 'See docs');
    });

    test('![alt] (image, no paren yet) is held entirely', () {
      expect(mend('Pic ![alt]', isComplete: false), 'Pic ');
    });

    test('![alt with no closing bracket yet is held entirely', () {
      expect(mend('Pic ![alt text bei', isComplete: false), 'Pic ');
    });

    test('a lone trailing ! is held - one more [ would start an image', () {
      expect(mend('Wow!', isComplete: false), 'Wow');
    });

    test('! not followed by [ is ordinary punctuation once released', () {
      // The '!' itself is only held while it is the very last character;
      // once anything else follows it, it is plainly not an image opener.
      expect(mend('Wow! That', isComplete: false), 'Wow! That');
    });

    test('a digit run at line start with no . yet is held (could be "1.")', () {
      expect(mend('Steps:\n\n1', isComplete: false), 'Steps:\n\n');
      expect(mend('Steps:\n\n12', isComplete: false), 'Steps:\n\n');
    });

    test('a digit run followed by real content is not held', () {
      expect(
        mend('Steps:\n\n12 apples', isComplete: false),
        'Steps:\n\n12 apples',
      );
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
