// B1-S6 round-6 invariant probe: the same shapes via the `.chatGPT()` and
// `.claude()` presets, not just the plain `StreamingTextMarkdown` default -
// the round-6 evidence's bug (3) specifically hit "the stream default,
// including .chatGPT() and .claude()" with the caret on.
@Timeout(Duration(seconds: 900))
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'markdown_fade_invariant_lib.dart';
import 'markdown_fade_invariant_docs.dart';

Widget _build(String preset, Stream<String>? s, String text) =>
    preset == 'chatGPT'
        ? StreamingTextMarkdown.chatGPT(text: text, stream: s)
        : StreamingTextMarkdown.claude(text: text, stream: s);

// The presets have their own padding/decoration (different from a bare
// `StreamingText`), so the bare-instant reference render must go through
// the SAME preset (with `revealMode: RevealMode.instant`) or the two frames
// are simply different sizes/layouts - a false-positive `pixDiff`, not a
// mask bug.
Widget _buildBare(String preset, String text) =>
    preset == 'chatGPT'
        ? StreamingTextMarkdown.chatGPT(
          text: text,
          revealMode: RevealMode.instant,
        )
        : StreamingTextMarkdown.claude(
          text: text,
          revealMode: RevealMode.instant,
        );

void main() {
  final cleanDocs = {
    ...dupDocs.map((k, v) => MapEntry('dup.$k', v)),
    'flash.ul': flashDocs['ul']!,
    'flash.longList': flashDocs['longList']!,
  };
  final reflowDocs = {'stale.longListReflow': staleDocs['listThenPara']!};

  for (final d in cleanDocs.entries) {
    for (final preset in ['chatGPT', 'claude']) {
      testWidgets(
        '$preset ${d.key}',
        (t) => go(
          t,
          'preset.$preset.${d.key}',
          d.value,
          gap: 3,
          build: (s, text) => _build(preset, s, text),
          buildBare: (text) => _buildBare(preset, text),
          // Known, documented gap for tables (B1-S6 round 6 "block-level
          // simplification" - see doc/BENCHMARKS.md and the sibling gap
          // documented in markdown_fade_verify3_test.dart/verify4_test.dart):
          // a genuinely new tail slot's append can be deferred long enough,
          // by an earlier slot's own case-4 hysteresis over the table's own
          // structural churn, that the content is already fully exposed by
          // the time it fires - so it pops instead of fades. The hard
          // dip invariant is unaffected (`go()` asserts it unconditionally
          // regardless of this flag).
          allowPops: d.key.contains('table'),
        ),
        tags: const ['fade_matrix'],
      );
    }
  }

  for (final d in reflowDocs.entries) {
    for (final preset in ['chatGPT', 'claude']) {
      testWidgets(
        '$preset ${d.key}',
        (t) => go(
          t,
          'preset.$preset.${d.key}',
          d.value,
          gap: 3,
          allowPops: true,
          build: (s, text) => _build(preset, s, text),
          buildBare: (text) => _buildBare(preset, text),
        ),
        tags: const ['fade_matrix'],
      );
    }
  }
}
