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

  group('an unclosed span is bounded to the current paragraph', () {
    test('a stray, never-closed \$ does not hold once its paragraph ends',
        () {
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
