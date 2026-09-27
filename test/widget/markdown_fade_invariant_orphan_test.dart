// B1-S6 round-6/7 invariant probe: content that recurs identically at a
// LATER, distinct tail slot. See `markdown_fade_invariant_docs.dart`'s
// [orphanDocs] doc - never a same-slot rewrite, so this must never pop
// (rounds 1-5's cross-slot "orphan pool" cleverness existed specifically
// to avoid re-fading this exact shape and, per the round-6 evidence, is
// what caused *other* content to pop or dip instead - the round-6 design
// does no cross-slot matching at all, so recurrence alone can't pop here) -
// EXCEPT `tableThenList`, bounded at ≤15% per B1F1 round 7 (see
// `markdown_fade_invariant_flash_test.dart`'s `_popCeiling` doc).
@Timeout(Duration(seconds: 900))
library;

import 'package:flutter_test/flutter_test.dart';
import 'markdown_fade_invariant_lib.dart';
import 'markdown_fade_invariant_docs.dart';

double _popCeiling(String doc) =>
    doc.toLowerCase().contains('table') ? 0.15 : 0.0;

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
            'orphan.${d.key}.chat.caret=$caret.gap$gap',
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
          'orphan.${d.key}.chunk.caret=$caret',
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
