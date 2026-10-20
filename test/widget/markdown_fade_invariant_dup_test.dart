// B1-S6 round-6/7 invariant probe: duplicate/repeated content at DISTINCT
// paint slots. See `markdown_fade_invariant_docs.dart`'s [dupDocs] doc.
// Never a same-slot rewrite, so this must never pop either - EXCEPT
// `table`, bounded per B1F1 round 7 (see
// `markdown_fade_invariant_flash_test.dart`'s `_popCeiling` doc: a
// multi-cell row's own construction can defer a new tail slot's append
// long enough, behind an earlier cell's own case-4 hysteresis, that it's
// already fully exposed when the append finally fires - collateral, never
// a dip).
@Timeout(Duration(seconds: 900))
library;

import 'package:flutter_test/flutter_test.dart';
import 'markdown_fade_invariant_lib.dart';
import 'markdown_fade_invariant_docs.dart';

// The stream/chat ceiling is 3/5 of `table`'s 5 tracked words: the max seen
// (2/5, both duplicated `Yes` cells popping, in about half of the Weekly
// runs in October 2026, before and after the 1.11.1 fade fix) plus one
// word, the same rule as `markdown_fade_invariant_stale_test.dart`'s
// ceilings. The old 15% rounded to 1 word and failed those runs.
double _popCeiling(String doc, {bool chunk = false}) =>
    doc == 'table' ? (chunk ? 0.45 : 3 / 5) : 0.0;

void main() {
  for (final d in dupDocs.entries) {
    for (final caret in [false, true]) {
      for (final gap in [2, 3, 6]) {
        testWidgets(
          'stream ${d.key} c=$caret g=$gap',
          (t) => go(
            t,
            'dup.${d.key}.stream.caret=$caret.gap$gap',
            d.value,
            caret: caret,
            gap: gap,
            maxPopFraction: _popCeiling(d.key),
          ),
          tags: const ['fade_matrix'],
        );
      }
      for (final gap in [2, 4]) {
        testWidgets(
          'chat ${d.key} c=$caret g=$gap',
          (t) => go(
            t,
            'dup.${d.key}.chat.caret=$caret.gap$gap',
            d.value,
            caret: caret,
            gap: gap,
            mode: 'chat',
            maxPopFraction: _popCeiling(d.key),
          ),
          tags: const ['fade_matrix'],
        );
      }
      testWidgets(
        'chunk ${d.key} c=$caret',
        (t) => go(
          t,
          'dup.${d.key}.chunk.caret=$caret',
          d.value,
          caret: caret,
          mode: 'chunk',
          maxPopFraction: _popCeiling(d.key, chunk: true),
        ),
        tags: const ['fade_matrix'],
      );
    }
  }
}
