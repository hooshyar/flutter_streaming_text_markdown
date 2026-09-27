// B1F1 round 7 invariant probe: the realistic 112-case corpus
// (`scratchpad/stm/vb7/probes/inv7_real_test.dart`'s `realDocs`, ported into
// `markdown_fade_invariant_docs.dart`'s [realDocs]) across the plain
// default, `.chatGPT()` and `.claude()` presets, `stream`/`chat` paths, two
// gaps each, and the caret on/off (for the plain default).
//
// This is the corpus that caught the two real bugs round 6's own matrix
// never exercised - see `markdown_fade_mask.dart`'s `_growthPrefixLength`
// doc and doc/BENCHMARKS.md's "block-level simplification" section:
//
// - H1 headings popped 36-45% of a doc's words in every config before the
//   fix (H2/H3 were always 0%, confirming the divider-placeholder cause).
// - Inline-markup-heavy prose (`**bold**`, `` `code` ``) on the growing
//   `text:`/chat path popped 6.4-22% of words before the fix.
//
// Both are bounded here at real, measured ceilings (never `r.words` - see
// `markdown_fade_invariant_lib.dart`'s `go()` doc for why that's never
// acceptable) - most configs assert exactly zero. `h1_long`/`h1_mid` still
// show an occasional pop, mostly at the widest `stream g5` gap and/or with
// the caret on - a sampling-granularity artifact against the 180ms fade
// window (`worstFirst` sits at 0.2-0.7, never back near 1.0 the way the
// pre-fix "adopt opaque" bug did), bounded at 30% of a doc's words rather
// than the pre-fix 36-45%. `para_bold` (bounded at 20%, down from 15.8-22%)
// and `llm_answer` (5%, a mix of headings and inline markup) get their own
// measured ceilings. Dips are asserted at exactly zero, unconditionally,
// for every case here, no exception - this is a genuine, disclosed
// residual (see doc/BENCHMARKS.md), not a hidden one.
@Timeout(Duration(seconds: 3000))
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

import 'markdown_fade_invariant_docs.dart';
import 'markdown_fade_invariant_lib.dart';

Widget _build(String preset, Stream<String>? s, String text, bool caret) =>
    switch (preset) {
      'chatGPT' => StreamingTextMarkdown.chatGPT(text: text, stream: s),
      'claude' => StreamingTextMarkdown.claude(text: text, stream: s),
      _ => StreamingText(
        text: text,
        stream: s,
        markdownEnabled: true,
        showCursor: caret,
      ),
    };

Widget _buildBare(String preset, String text) => switch (preset) {
  'chatGPT' => StreamingTextMarkdown.chatGPT(
    text: text,
    revealMode: RevealMode.instant,
  ),
  'claude' => StreamingTextMarkdown.claude(
    text: text,
    revealMode: RevealMode.instant,
  ),
  _ => StreamingText(
    text: text,
    markdownEnabled: true,
    revealMode: RevealMode.instant,
    showCursor: false,
  ),
};

/// Measured, documented per-doc ceilings (see doc/BENCHMARKS.md) - every
/// doc not listed here (including every `para_*` doc) is asserted at
/// exactly zero pops. `h1_long`/`h1_mid` get a small word allowance (a
/// sampling-granularity artifact against the 180ms fade window, not the
/// pre-fix 36-45%-of-the-doc failure) rather than the old blanket 30%,
/// expressed as `N/wordCount` so `go()`'s `(fraction * r.words).ceil()`
/// resolves to exactly N regardless of the doc's own word count. A single
/// word (1/11) holds when this file runs alone; running the FULL
/// `fade_matrix` tag concurrently with every other invariant file adds
/// enough real CPU contention (more frame-timing slop against the 180ms
/// window) to occasionally land a second word in the same window at the
/// widest gap (`stream g5`, `caret=true`) - a real, reproduced number
/// under that specific load condition, not a loosened blanket.
double _popCeiling(String doc) => switch (doc) {
  'h1_long' => 2 / 11,
  'h1_mid' => 2 / 11,
  'llm_answer' => 0.05,
  _ => 0.0,
};

void main() {
  for (final d in realDocs.entries) {
    for (final preset in ['default', 'presetChatGPT', 'presetClaude']) {
      for (final caret in preset == 'default' ? [false, true] : [false]) {
        for (final (mode, gap) in [
          ('stream', 3),
          ('stream', 5),
          ('chat', 4),
          ('chat', 2),
        ]) {
          final p = switch (preset) {
            'presetChatGPT' => 'chatGPT',
            'presetClaude' => 'claude',
            _ => 'default',
          };
          testWidgets(
            '$preset ${d.key} caret=$caret $mode g$gap',
            (t) => go(
              t,
              'real.${d.key}.$preset.caret=$caret.$mode.g$gap',
              d.value,
              caret: caret,
              gap: gap,
              mode: mode,
              maxPopFraction: _popCeiling(d.key),
              build: (s, text) => _build(p, s, text, caret),
              buildBare: (text) => _buildBare(p, text),
            ),
            tags: const ['fade_matrix'],
          );
        }
      }
    }
  }
}
