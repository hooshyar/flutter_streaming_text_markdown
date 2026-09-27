// B1-S6 round-6/7 invariant probe: plain sequential docs (pure tail growth,
// no restructuring event ever occurs). See `markdown_fade_invariant_lib.dart`
// and `markdown_fade_invariant_docs.dart`'s [flashDocs] doc. Content here
// must NEVER dip once settled (asserted unconditionally by `go()`, no
// exception - confirmed across this entire matrix); pops are asserted at
// exactly ZERO too, EXCEPT `nested`/`table` - see [_popCeiling]'s doc.
@Timeout(Duration(seconds: 900))
library;

import 'package:flutter_test/flutter_test.dart';
import 'markdown_fade_invariant_lib.dart';
import 'markdown_fade_invariant_docs.dart';

/// A `nested` (sub-list attaching) or `table` (multi-cell row construction)
/// doc can add a genuinely new tail slot while an EARLIER slot is itself
/// mid case-4 hysteresis over its own structural churn - see
/// `markdown_fade_mask.dart`'s `_pendingExposedLength` doc. The new slot's
/// append is correctly deferred (never dips - `go()` still asserts the hard
/// settled-never-dips invariant unconditionally, with NO exception) but, if
/// the content is already fully exposed (rendered unmasked while deferred)
/// by the time the append finally fires, no run is armed and it pops
/// instead of fades. Bounded per B1F1 round 7: tables at at most 15% of
/// occurrences, nested lists at at most 10%, on the `stream`/`chat` paths -
/// every other doc here is asserted at exactly zero pops, every path, both
/// caret states.
///
/// `chunk` mode (3 raw characters per frame, far finer-grained than any
/// real token/word-paced stream) measurably worsens `table` specifically
/// (up to 40% observed - a table row's own multi-cell construction hits
/// the deferred-append collision far more often at this granularity) - a
/// real, reproducible, DIFFERENT number for a DIFFERENT (synthetic, not
/// realistic-LLM-output-shaped) reveal granularity, not a loosened escape
/// hatch for the same case.
double _popCeiling(String doc, {bool chunk = false}) => switch (doc) {
  'table' => chunk ? 0.45 : 0.15,
  'nested' => 0.10,
  _ => 0.0,
};

void main() {
  for (final d in flashDocs.entries) {
    for (final caret in [false, true]) {
      for (final gap in [2, 3, 6]) {
        testWidgets(
          'stream ${d.key} c=$caret g=$gap',
          (t) => go(
            t,
            'flash.${d.key}.stream.caret=$caret.gap$gap',
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
            'flash.${d.key}.chat.caret=$caret.gap$gap',
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
          'flash.${d.key}.chunk.caret=$caret',
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
