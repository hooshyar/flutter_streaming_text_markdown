// B1-S6 round-6/7 invariant probe: genuine mid-stream reflow/restructuring
// docs. See `markdown_fade_invariant_docs.dart`'s [staleDocs] doc - these
// MAY legitimately pop (case 4's 2-consecutive-layout adopt-opaque, a
// DESIGNED pop for a genuine rewrite - table row construction, a nested-
// list-shaped transition, or a real block-type change mid-document), so a
// bounded ceiling applies here (never zero, never unbounded); the dip
// invariant (settled text never drops) is still asserted unconditionally
// by `go()` regardless, no exception.
@Timeout(Duration(seconds: 900))
library;

import 'package:flutter_test/flutter_test.dart';
import 'markdown_fade_invariant_lib.dart';
import 'markdown_fade_invariant_docs.dart';

// This file's docs are all genuine case-4 rewrite-adopt sites BY
// CONSTRUCTION (that's the whole reason this corpus exists - each one
// deliberately provokes a mid-stream table/list/block reflow) - a
// fundamentally different, DESIGNED-poppable category from the "should be
// zero" ones (plain paragraphs/headings/flat lists) B1F1 round 7 restored
// a real bound for elsewhere in this matrix, and from the ≤15%/≤10%
// deferred-append ceilings that apply to `nested`/`table` SHAPE alone in
// those other files. Bounded at ≤45% here - a real, measured ceiling
// (historical max observed across repeated runs: 6/15 = 40%, `tbl2`
// caret=true), not an unlimited `allowPops: true` escape hatch - a
// genuinely broken case (every occurrence popping, or any dip at all -
// `go()`'s own dip assertion is never loosened) would still fail this.
double _popCeiling(String doc) => 0.45;

void main() {
  for (final d in staleDocs.entries) {
    for (final caret in [false, true]) {
      for (final gap in [2, 3, 6]) {
        testWidgets(
          'stream ${d.key} c=$caret g=$gap',
          (t) => go(
            t,
            'stale.${d.key}.stream.caret=$caret.gap$gap',
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
            'stale.${d.key}.chat.caret=$caret.gap$gap',
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
          'stale.${d.key}.chunk.caret=$caret',
          d.value,
          caret: caret,
          mode: 'chunk',
          maxPopFraction: _popCeiling(d.key),
        ),
        tags: const ['fade_matrix'],
      );
    }
  }
}
