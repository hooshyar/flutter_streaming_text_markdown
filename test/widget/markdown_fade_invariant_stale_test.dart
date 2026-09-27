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
// `tbl2`/`tbl2adj`/`tblThenList` (each provokes a genuine table-row
// reflow) may legitimately pop. `listThenPara`, `olThenUl`, `setext` and
// `hrs` never touch a table and are asserted at EXACTLY zero on every
// path/mode - B1F1 round 7's fix restored a real bound for the block-level
// churn this corpus exercises (list-item re-ordering, a setext/hr line
// resolving). `mixed` contains a table cell alongside a list/quote/code
// block, so it inherits the table ceiling ONLY in `chunk` mode, where the
// table's own reflow can coincide with the finer-grained reveal; on the
// realistic `stream`/`chat` paths it is zero like the other non-table docs.
//
// `chunk` mode (3 raw characters/frame - far finer-grained than any real
// token/word-paced stream) measurably worsens the table docs specifically:
// historical max observed across repeated runs on this machine was 36-40%
// (`tbl2`, caret=true) - a real, reproducible, DIFFERENT number for a
// DIFFERENT (synthetic) reveal granularity, not a loosened escape hatch;
// flagged here (and in doc/BENCHMARKS.md) rather than silently absorbed
// into a blanket ceiling that also covered docs which never pop at all.
//
// `tbl2` itself (15 tracked words, two SEPARATE 2x2 tables in one doc) is
// measurably noisier than `tbl2adj`/`tblThenList` even on the `stream`/
// `chat` (non-chunk) paths - repeated `caret=true gap=2` runs on this
// machine landed 3-5 pops/15 (20-33%), not the <=15% the other two table
// docs hold to. This is a real, reproducibly-measured number, not the
// original blanket 0.45 covering every doc regardless of shape - see
// doc/BENCHMARKS.md.
double _popCeiling(String doc, {bool chunk = false}) => switch (doc) {
  'tbl2' => 0.40,
  'tbl2adj' || 'tblThenList' => chunk ? 0.40 : 0.15,
  'mixed' => chunk ? 0.15 : 0.0,
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
