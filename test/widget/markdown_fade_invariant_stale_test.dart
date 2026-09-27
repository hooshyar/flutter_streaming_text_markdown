// B1-S6 round-6 invariant probe: genuine mid-stream reflow/restructuring
// docs. See `markdown_fade_invariant_docs.dart`'s [staleDocs] doc - these
// MAY legitimately pop (case 4's 2-consecutive-layout adopt-opaque), so
// `allowPops: true` here; the dip invariant (settled text never drops) is
// still asserted unconditionally by `go()` regardless.
@Timeout(Duration(seconds: 900))
library;

import 'package:flutter_test/flutter_test.dart';
import 'markdown_fade_invariant_lib.dart';
import 'markdown_fade_invariant_docs.dart';

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
            allowPops: true,
          ),
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
            allowPops: true,
          ),
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
          allowPops: true,
        ),
      );
    }
  }
}
