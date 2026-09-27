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
// deliberately provokes a mid-stream table/list/block reflow), but only
// `tbl2`/`tbl2adj`/`tblThenList`/`mixed` (each contains a table cell, the
// actual source of the deferred-append collision - see
// `markdown_fade_mask.dart`'s `_pendingExposedLength` doc) may legitimately
// pop. `listThenPara`, `olThenUl`, `setext` and `hrs` never touch a table
// and are asserted at EXACTLY zero on every path/mode - confirmed to hold
// at exactly 0% across every run in this slice's own re-measurement (see
// doc/BENCHMARKS.md's B1-S6 round 9 section).
//
// Every non-zero ceiling below is `(max observed word count across 4
// repeated runs on this machine, 2 of them with the default suite running
// concurrently as load) + 1 word`, expressed as `N/wordCount` so `go()`'s
// `(fraction * r.words).ceil()` resolves to exactly `N` regardless of the
// doc's own tracked-word count - NOT the round-8 blanket 0.40/0.15 (those
// were guesses; `tbl2adj`'s own `chunk` case measured 45.5%, i.e.
// EXACTLY at the round-8 ceiling, and `stream` measured up to 27% against
// a 15% ceiling - both flakes this round's re-measurement fixes). See
// doc/BENCHMARKS.md's round 9 section for the raw per-run numbers.
double _popCeiling(String doc, {bool chunk = false}) => switch (doc) {
  'tbl2' => chunk ? 7 / 15 : 6 / 15, // max seen 6/15 chunk, 5/15 stream
  'tbl2adj' => chunk ? 6 / 11 : 4 / 11, // max seen 5/11 chunk, 3/11 stream
  'tblThenList' => chunk ? 4 / 12 : 2 / 12, // max seen 3/12 chunk, 1/12 stream
  'mixed' => 2 / 25, // max seen 1/25, any path (stream/chat/chunk alike)
  _ => 0.0,
};

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
          maxPopFraction: _popCeiling(d.key, chunk: true),
        ),
        tags: const ['fade_matrix'],
      );
    }
  }
}
