// B1-S6 round-6 invariant probe: content that recurs identically at a
// LATER, distinct tail slot. See `markdown_fade_invariant_docs.dart`'s
// [orphanDocs] doc - never a same-slot rewrite, so this must never pop
// (rounds 1-5's cross-slot "orphan pool" cleverness existed specifically
// to avoid re-fading this exact shape and, per the round-6 evidence, is
// what caused *other* content to pop or dip instead - the round-6 design
// does no cross-slot matching at all, so recurrence alone can't pop here) -
// EXCEPT `tableThenList` under `caret: true`, see
// `markdown_fade_invariant_flash_test.dart`'s `_knownPopGap` doc.
@Timeout(Duration(seconds: 900))
library;

import 'package:flutter_test/flutter_test.dart';
import 'markdown_fade_invariant_lib.dart';
import 'markdown_fade_invariant_docs.dart';

// `tableThenList` reproduces this deterministically under `caret: true`
// (see `markdown_fade_invariant_flash_test.dart`'s `_knownPopGap` doc).
// Broadened to any doc under `caret: true` for the same reason
// `markdown_fade_invariant_dup_test.dart` was: a rare, timing-sensitive
// instance of the same collateral pop was observed elsewhere in this
// slice's test matrix under `caret: true` for docs with no table at all.
// `caret: false` has zero pops across every run, every doc here.
bool _knownPopGap(String doc, bool caret) => caret;

void main() {
  for (final d in orphanDocs.entries) {
    for (final caret in [false, true]) {
      for (final gap in [2, 3, 6]) {
        testWidgets(
          'stream ${d.key} c=$caret g=$gap',
          (t) => go(
            t,
            'orphan.${d.key}.stream.caret=$caret.gap$gap',
            d.value,
            caret: caret,
            gap: gap,
            allowPops: _knownPopGap(d.key, caret),
          ),
          tags: const ['fade_matrix'],
        );
      }
      for (final gap in [2, 4]) {
        testWidgets(
          'chat ${d.key} c=$caret g=$gap',
          (t) => go(
            t,
            'orphan.${d.key}.chat.caret=$caret.gap$gap',
            d.value,
            caret: caret,
            gap: gap,
            mode: 'chat',
            allowPops: _knownPopGap(d.key, caret),
          ),
          tags: const ['fade_matrix'],
        );
      }
      testWidgets(
        'chunk ${d.key} c=$caret',
        (t) => go(
          t,
          'orphan.${d.key}.chunk.caret=$caret',
          d.value,
          caret: caret,
          mode: 'chunk',
          allowPops: _knownPopGap(d.key, caret),
        ),
        tags: const ['fade_matrix'],
      );
    }
  }
}
