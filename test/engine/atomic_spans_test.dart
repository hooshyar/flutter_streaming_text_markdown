// AtomicSpanDetector currency-vs-math regression coverage (W11 follow-up).
//
// Ported from the deleted `LaTeXProcessor`'s false-positive cases (see
// `git show 38bc831:test/latex_processor_test.dart`) plus the new
// `rewriteDollarDelimiters` used by the render path instead of forwarding
// `useDollarSignsForLatex` to `gpt_markdown` directly.

import 'package:flutter_streaming_text_markdown/src/engine/atomic_spans.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const detector = AtomicSpanDetector();

  group('currency false positives are never treated as LaTeX spans', () {
    for (final text in <String>[
      'Price: \$5',
      'Cost \$10 - \$20',
      '\$ alone',
      'I have \$5 and you have \$10',
    ]) {
      test('"$text" produces no spans', () {
        expect(detector.spans(text), isEmpty);
      });

      test('"$text" is left untouched by rewriteDollarDelimiters', () {
        expect(detector.rewriteDollarDelimiters(text), text);
      });
    }
  });

  group('genuine LaTeX is still detected and rewritten', () {
    test('a simple inline expression is a closed span', () {
      final spans = detector.spans(r'See $x=1$ please');
      expect(spans, hasLength(1));
      expect(spans.single.closed, isTrue);
      expect(spans.single.start, 4);
      expect(spans.single.end, 9);
    });

    test(r'$x^2$ rewrites to \(x^2\)', () {
      expect(
        detector.rewriteDollarDelimiters(r'formula $x^2$ done'),
        r'formula \(x^2\) done',
      );
    });

    test(r'$$\frac{a}{b}$$ rewrites to \[\frac{a}{b}\]', () {
      expect(
        detector.rewriteDollarDelimiters(r'block $$\frac{a}{b}$$ done'),
        r'block \[\frac{a}{b}\] done',
      );
    });

    test('currency next to real math: only the math is rewritten', () {
      expect(
        detector.rewriteDollarDelimiters(r'Price: $5, and $x=1$ is math'),
        r'Price: $5, and \(x=1\) is math',
      );
    });
  });

  group('code fences and inline code are never touched', () {
    test('shell \$VARS inside a fenced code block produce no spans', () {
      const text = '```bash\nexport PATH=\$HOME/bin:\$PATH\n```';
      expect(detector.spans(text), isEmpty);
      expect(detector.rewriteDollarDelimiters(text), text);
    });

    test('inline \$HOME code stays literal', () {
      const text = 'Run `\$HOME` please';
      expect(detector.spans(text), isEmpty);
      expect(detector.rewriteDollarDelimiters(text), text);
    });
  });

  group('escaped dollars are never treated as LaTeX delimiters (R2 fix)', () {
    test(r'Literal \$x and \$y here. (fails on 189b826: bogus Math span + '
        'ParseException)', () {
      const text = r'Literal \$x and \$y here.';
      expect(detector.spans(text), isEmpty);
      expect(detector.rewriteDollarDelimiters(text), text);
    });

    test(r'a real span still works right after an escaped dollar', () {
      const text = r'Literal \$x, and $a=1$ is math.';
      final spans = detector.spans(text);
      expect(spans, hasLength(1));
      expect(text.substring(spans.single.start, spans.single.end), r'$a=1$');
      expect(
        detector.rewriteDollarDelimiters(text),
        r'Literal \$x, and \(a=1\) is math.',
      );
    });

    test(r'\$$ (escaped dollar immediately before a live one) does not '
        r'open a $$ block span', () {
      const text = r'\$$a=1$';
      // The first `$` is escaped and literal; `_dollarDollar` never
      // matches here, so the second `$` and the `$` that follows `a=1`
      // form an ordinary single-dollar span instead.
      final spans = detector.spans(text);
      expect(spans, hasLength(1));
      expect(text.substring(spans.single.start, spans.single.end), r'$a=1$');
    });

    test('an even run of backslashes leaves the dollar live: '
        r'\\$x^2$ still opens math', () {
      const text = r'\\$x^2$ done';
      final spans = detector.spans(text);
      expect(spans, hasLength(1));
      expect(text.substring(spans.single.start, spans.single.end), r'$x^2$');
    });
  });

  group('currency magnitude suffixes are still currency (advisory)', () {
    for (final text in <String>[
      r'Growth from $10k-$20k happened.',
      r'Revenue was $5M last year.',
    ]) {
      test('"$text" produces no spans', () {
        expect(detector.spans(text), isEmpty);
      });
    }
  });

  group('digit-minus math is not mistaken for a currency range', () {
    // Regression: `after == '-'` used to make ANY `$<digits>-...` currency,
    // so `$1-p$`, `$2k-1$`, `$1-\alpha$`, `$3m-2$`, `$0-1$` all showed raw.
    // `-` only counts as a boundary when it starts a `-$` currency range.
    for (final text in <String>[
      r'$1-p$',
      r'$2k-1$',
      r'$1-\alpha$',
      r'$3m-2$',
      r'$0-1$',
    ]) {
      test('"$text" produces a closed math span', () {
        final spans = detector.spans(text);
        expect(spans, hasLength(1));
        expect(spans.single.closed, isTrue);
        expect(text.substring(spans.single.start, spans.single.end), text);
      });
    }

    for (final text in <String>[
      r'$10-$20',
      r'$10k-$20k',
      r'Range: $10 - $20 done',
    ]) {
      test('"$text" stays currency (no spans)', () {
        expect(detector.spans(text), isEmpty);
        expect(detector.rewriteDollarDelimiters(text), text);
      });
    }

    test('a lone trailing "-" with nothing after it yet does not hold '
        '(still streaming)', () {
      // `$10-` mid-stream could still become `$10-$20`: ambiguous, so the
      // same don't-hold rule as a bare trailing `$5` applies.
      expect(detector.spans(r'Costs $10-'), isEmpty);
    });
  });

  group('existing currency and math cases still hold', () {
    for (final text in <String>[
      r'$5',
      r'$5 and $10',
      r'$10 - $20',
      r'$10-$20',
      r'$10k-$20k',
      r'$5M',
      r'$2B,',
      r'Price: $5',
    ]) {
      test('"$text" produces no spans', () {
        expect(detector.spans(text), isEmpty);
      });
    }

    for (final text in <String>[
      r'$k$',
      r'$M$',
      r'$x_k$',
      r'$2k+1$',
      r'$10k$',
      r'$x^2$',
      r'$1-p$',
      r'$2k-1$',
      r'$1-\alpha$',
      r'$3m-2$',
      r'$0-1$',
    ]) {
      test('"$text" produces a math span', () {
        expect(detector.spans(text), isNotEmpty);
      });
    }
  });

  group('an unclosed span is bounded to the current paragraph', () {
    test('a stray, never-closed \$ does not hold once its paragraph ends', () {
      const text = 'First \$paragraph never closes.\n\nSecond paragraph.';
      // No span spills across the blank line into the next paragraph.
      expect(detector.spans(text), isEmpty);
    });

    test('an unclosed span within an unfinished paragraph is still held '
        'back (mid-stream)', () {
      // Still-open source: the paragraph hasn't ended yet, so this is
      // ambiguous and must stay withheld until it does (or closes).
      final spans = detector.spans(r'See $x=1 still typing');
      expect(spans, hasLength(1));
      expect(spans.single.closed, isFalse);
    });
  });
}
