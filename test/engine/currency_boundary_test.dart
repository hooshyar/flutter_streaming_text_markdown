// B1-S3 currency boundary coverage: markdown emphasis/strikethrough
// markers around an amount, en/em-dash ranges, and multi-char magnitude
// suffixes must all keep a `$N` token classified as currency, while the
// real-math and safety guards from Phase A stay intact.

import 'package:flutter_streaming_text_markdown/src/engine/atomic_spans.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const detector = AtomicSpanDetector();

  group('markdown markers adjacent to an amount keep it currency', () {
    // `*`, `_` and `~` are currency-boundary punctuation, so an amount
    // wrapped for bold/italic/strikethrough never opens a math span.
    for (final text in <String>[
      r'**$20**',
      r'_$5_',
      r'~~$5~~',
      r'It costs **$20** today',
      r'Price: _$5_ each',
      r'Was ~~$9.99~~ now $4.99',
      r'*$7*',
    ]) {
      test('"$text" produces no spans', () {
        expect(detector.spans(text), isEmpty);
      });

      test('"$text" is left untouched by rewriteDollarDelimiters', () {
        expect(detector.rewriteDollarDelimiters(text), text);
      });
    }

    test('real math still works next to marked-up currency', () {
      const text = r'Was **$20** but $x=1$ holds';
      final spans = detector.spans(text);
      expect(spans, hasLength(1));
      expect(spans.single.closed, isTrue);
      expect(text.substring(spans.single.start, spans.single.end), r'$x=1$');
    });
  });

  group('en dash and em dash are currency range joiners', () {
    for (final text in <String>[
      r'$5–10',
      r'$5—$10',
      r'$5–$10',
      r'$5—10',
      r'Plans cost $5–10 per month',
      r'Roughly $20—30/month here',
      r'Range $10–$20 done',
    ]) {
      test('"$text" produces no spans', () {
        expect(detector.spans(text), isEmpty);
      });

      test('"$text" is left untouched by rewriteDollarDelimiters', () {
        expect(detector.rewriteDollarDelimiters(text), text);
      });
    }

    test('a trailing en dash mid-stream does not hold the reveal', () {
      expect(detector.spans(r'Costs $5–'), isEmpty);
    });

    test('an en-dash range does not swallow later math', () {
      const text = r'$5–10 per month, or $x$';
      final spans = detector.spans(text);
      expect(spans, hasLength(1));
      expect(spans.single.closed, isTrue);
      expect(text.substring(spans.single.start, spans.single.end), r'$x$');
    });
  });

  group('multi-char magnitude suffixes are still currency', () {
    for (final text in <String>[
      r'$5bn',
      r'$5mn',
      r'$5tn',
      r'Revenue hit $12bn last year',
      r'A $2.5tn market, growing',
      r'Raised $300mn, they said',
    ]) {
      test('"$text" produces no spans', () {
        expect(detector.spans(text), isEmpty);
      });

      test('"$text" is left untouched by rewriteDollarDelimiters', () {
        expect(detector.rewriteDollarDelimiters(text), text);
      });
    }

    test(r'a suffix on the far end of a range still resolves ($5-10bn)', () {
      expect(detector.spans(r'Worth $5-10bn total'), isEmpty);
    });
  });

  group('guards: real math still opens', () {
    for (final text in <String>[
      r'$x^2$',
      r'$1-p$',
      r'$2k-1$',
      r'$0-1$',
      r'$1-\alpha$',
      r'$k$',
      r'$M$',
    ]) {
      test('"$text" produces exactly one closed math span', () {
        final spans = detector.spans(text);
        expect(spans, hasLength(1));
        expect(spans.single.closed, isTrue);
        expect(text.substring(spans.single.start, spans.single.end), text);
      });
    }
  });

  group('guards: cap, escaping and code skipping are unchanged', () {
    test('an unclosed single-\$ span is still capped at 32 units', () {
      const text =
          r'See $HOME_DIRECTORY_value and then a long trailing sentence '
          'with many words';
      expect(detector.spans(text).where((s) => !s.closed), isEmpty);
    });

    test(r'escaped \$ amounts produce no spans', () {
      const text = r'Escaped \$5 and \$10';
      expect(detector.spans(text), isEmpty);
      expect(detector.rewriteDollarDelimiters(text), text);
    });

    test(r'$ inside fenced and inline code produces no spans', () {
      const fenced = '```\nPrice: **\$5**\n```';
      const inline = r'run `$5bn` now';
      expect(detector.spans(fenced), isEmpty);
      expect(detector.spans(inline), isEmpty);
    });
  });
}
