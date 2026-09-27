// B1-S6 round-6 invariant probe: a SMALL representative smoke subset of
// `markdown_fade_invariant_*_test.dart`'s exhaustive `fade_matrix`, kept in
// the DEFAULT test run so the fast check still exercises this mask's core
// invariant (settled text never dips) without paying the exhaustive
// matrix's cost (the full matrix took the default suite from ~40s to
// ~5min - see dart_test.yaml's `fade_matrix` tag and
// `.github/workflows/weekly.yml`'s `fade-matrix` job for the full run).
//
// Deliberately narrow coverage, one representative case per axis:
// - the `chat` (growing `text:`) path at a coarse gap (4) for a `ul` and a
//   `table` - the two doc shapes most likely to regress (see
//   `markdown_fade_invariant_flash_test.dart`'s `_knownPopGap` doc);
// - a `stream` at gap 6 for an `ol`, via the `.chatGPT()` preset with the
//   caret on - covers the preset wiring and caret path together;
// - the `'- Yes'` x3 duplicate-content case;
// - the epoch/reset case (a brand new document replacing an in-flight one);
// - one heading/paragraph doc.
@Timeout(Duration(seconds: 900))
library;

import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

import 'markdown_fade_invariant_docs.dart';
import 'markdown_fade_invariant_lib.dart';

void main() {
  testWidgets(
    'chat ul c=false g=4',
    (t) => go(
      t,
      'smoke.flash.ul.chat.caret=false.gap4',
      flashDocs['ul']!,
      gap: 4,
      mode: 'chat',
    ),
  );

  testWidgets(
    'chat table c=true g=4',
    (t) => go(
      t,
      'smoke.flash.table.chat.caret=true.gap4',
      flashDocs['table']!,
      caret: true,
      gap: 4,
      mode: 'chat',
      allowPops: true,
    ),
  );

  testWidgets(
    'chatGPT preset stream ol c=true g=6',
    (t) => go(
      t,
      'smoke.preset.chatGPT.flash.ol.stream.caret=true.gap6',
      flashDocs['ol']!,
      caret: true,
      gap: 6,
      build: (s, text) => StreamingTextMarkdown.chatGPT(text: text, stream: s),
      buildBare:
          (text) => StreamingTextMarkdown.chatGPT(
            text: text,
            revealMode: RevealMode.instant,
          ),
    ),
  );

  testWidgets(
    "dup '- Yes' x3",
    (t) => go(t, 'smoke.dup.ulYes.stream.caret=false.gap3', dupDocs['ulYes']!),
  );

  testWidgets('epoch reset', epochResetCase);

  testWidgets(
    'headings doc',
    (t) => go(
      t,
      'smoke.flash.headings.stream.caret=false.gap3',
      flashDocs['headings']!,
    ),
  );
}
