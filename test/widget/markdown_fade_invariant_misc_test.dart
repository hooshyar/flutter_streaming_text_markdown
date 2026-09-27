// B1-S6 round-6 invariant probe: the `**` mid-stream closing-rewrite case,
// and an epoch/reset sequence (a brand new document replacing an in-flight
// one) sampled with the strict per-occurrence invariant harness.
@Timeout(Duration(seconds: 900))
library;

import 'package:flutter_test/flutter_test.dart';

import 'markdown_fade_invariant_lib.dart';

void main() {
  group('bold `**` mid-stream closing rewrite', () {
    const doc =
        'Alpha **bravo charlie** delta echo foxtrot **golf hotel** india. ';
    for (final caret in [false, true]) {
      for (final mode in ['stream', 'chunk']) {
        testWidgets(
          'mode=$mode caret=$caret',
          (t) => go(
            t,
            'misc.boldRewrite.$mode.caret=$caret',
            doc,
            caret: caret,
            gap: 2,
            mode: mode,
          ),
          tags: const ['fade_matrix'],
        );
      }
    }
  });

  group('epoch reset: a brand new document mid-stream', () {
    testWidgets(
      'never dips and settles to the new doc, caret off',
      epochResetCase,
      tags: const ['fade_matrix'],
    );
  });
}
