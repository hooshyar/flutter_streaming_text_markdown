# Benchmarks

## Streaming markdown vs bare `GptMarkdown` (acceptance criterion 8)

`test/perf/stream_benchmark_test.dart` streams a 400px-wide, ~20k-char
markdown document from a real `Stream<String>` to a `StreamingText` widget
(default caret **on**, pulsing, for the whole reveal) and separately grows an
equivalent plain `GptMarkdown` (`bare`) at the same pace. `ours` and `bare`
never share a build: each is mounted alone, pumped to completion, and fully
torn down before the other starts (`_measureOurs` / `_measureBare`), across
several short alternating rounds, so neither side's ticker/timer cost is ever
charged to the other and a transient burst of unrelated system load lands on
the pooled sample for both sides rather than skewing just one.

The test is tagged `benchmark` in `dart_test.yaml` (skipped by default;
`flutter test --tags benchmark --run-skipped` to run it) since a wall-clock,
ratio-based assertion is inherently noisier than the rest of the suite —
this is the one sanctioned wall-clock assertion (acceptance criterion 11).

**Budget:** median frame-time ratio (ours / bare) ≤ 1.8x, element-rebuild
ratio ≤ 6x. **Target:** ~1.3x time.

### Phase C caret-performance regression and fix (2026-09-27)

**The regression.** The previous version of this benchmark ran `showCursor:
false` (the caret entirely off - the exact surface that had regressed) with
both widgets interleaved in one shared tree, so it reported ~1.0x and missed
the bug completely. The verifier's own separate measurement, with the
default caret actually on, found:

| | p50 (frame) | element rebuilds |
|---|---|---|
| `StreamingText` (caret on, buggy) | 16.9 ms | 249,855 |
| bare `GptMarkdown` | 1.77 ms | ~5,200 |
| **ratio** | **~9.5x** | **~48x** |

Cause: while the caret showed, `_buildContent` called
`withCaretPattern(widget.markdownOptions, caretInlinePattern(caret))` every
tick, allocating a fresh `RegExp`, a fresh `InlinePattern`, and a fresh
`MarkdownRenderOptions` each time. `gpt_markdown`'s segment cache
(`GptMarkdownConfig.isSame`) compares `inlinePatterns` with `listEquals`,
which falls back to **element identity** for `InlinePattern` (it has no value
equality) — so a brand new instance every frame looked like a config change
on every frame and dropped the whole segment cache, every tick, for the
entire stream.

**The fix** (`lib/src/render/caret_inline.dart`,
`lib/src/render/streaming_caret.dart`,
`lib/src/streaming/streaming_text.dart`):

1. `caretInlinePattern` now takes a `Widget Function()` builder and is built
   ONCE per `State` (`_ensureCaretInlinePattern`), over a module-level
   `static final RegExp`. The pattern's identity never changes across
   builds; only what the builder returns (the caret's current color) does.
2. `_effectiveMarkdownOptions()` caches the resulting `MarkdownRenderOptions`
   and only rebuilds it when `widget.markdownOptions` itself changes
   identity — never on a caret pulse or reveal tick.
3. `StreamingCaret` now takes a `ValueListenable<double> opacity` and
   repaints itself via `ValueListenableBuilder` - the caret pulse updates
   this notifier directly from the shared ticker (`_onTick`) without calling
   `setState` on the whole `StreamingText` (and therefore without touching
   the markdown subtree at all) unless the reveal is actually progressing or
   a fade is actually settling.

**Proof it's real:** the rewritten benchmark (non-interleaved, caret
genuinely on, `test/perf/stream_benchmark_test.dart`) FAILS on the
pre-fix commit (`60c2f4b`) and PASSES on the fix commit, verified from a
scratch `git worktree add 60c2f4b`:

| | time ratio | element-rebuild ratio | result |
|---|---|---|---|
| Base (`60c2f4b`, buggy) | 4.723x | 11.298x | **FAIL** (budget 1.8x / 6x) |
| Fixed (this commit) | ~1.66x–1.78x (8-round pooled median, several runs) | 2.567x | **PASS** |

The element-rebuild ratio is the more reliable signal here (deterministic,
load-independent): it dropped from **11.3x** (this benchmark's own pacing;
the verifier's separately-paced repro saw **~48x**) to a stable **2.567x** —
the caret's own genuinely-necessary extra widgets (`StreamingCaret`, its
`ValueListenableBuilder`, the `WidgetSpan`'s per-frame `MediaQuery`/`Builder`
wrap that `gpt_markdown` applies to any inline `WidgetSpan` for text-scaling
correctness), not a cache-dropping bug. The time ratio is wall-clock and
therefore sensitive to this (shared, multi-agent) dev machine's load; pooling
8 alternating short rounds (`ours`, `bare`, `ours`, `bare`, ...) instead of
one long block each brought it from a noisy 1.4x–2.8x spread down to a
consistent ~1.7x across seven consecutive runs.

Environment: Flutter (stable), `gpt_markdown: ^1.3.0`, `flutter test`'s
default VM (debug mode; release-mode numbers would be lower for both sides
but the *ratio* is what's asserted). Machine was concurrently running two
other unrelated agent sessions during measurement (load average ~5-7); a
quieter machine should land closer to the ~1.3x target.

## Reveal delegation decision (B1-S4, acceptance criterion 11)

`test/perf/delegation_benchmark_test.dart` measures four arms on the same
20k-char growing markdown document, 400px wide, 16ms frames, 6 alternating
rounds, against the rule fixed in advance in `PHASE-B1-PLAN.md`'s "Decision:
keep our engine and delegate only the per-word paint":

> RULE: adopt the hybrid if the markdown stream is ≤1.8x bare, final==source,
> and no timer is still pending 400ms after `isStreaming` goes false.
> Otherwise markdown smoothFade becomes word-paced with no alpha, and plain
> text keeps our fade_span.

### The four arms

- **(A) ours today** — `StreamingText` driving `GptMarkdown` with no reveal
  delegation at all (the existing engine owns pacing, caret and paint).
- **(B) the hybrid** — our code still grows the revealed `data` string
  (mirroring our engine's cursor, one chunk per 16ms tick, same as bare);
  `GptMarkdown` is only asked to paint that already-revealed head, via
  `animation: GptMarkdownAnimation.fade`, `revealFadeSeconds: 0.18` and a
  deliberately huge `charactersPerSecond` (1,000,000) so its own pacing never
  lags our cursor — it purely fades whatever we hand it, exactly as the
  design describes ("gpt_markdown's fade already styles whole words").
- **(C) full delegation** — `GptMarkdown` owns *everything*: mounted once
  with the whole final text and `isStreaming: true`, revealing it on its own
  clock at its own default `charactersPerSecond` (300) and
  `revealFadeSeconds: 0.18`. This is the literal "hand it over and let it
  drive" integration the rejection list warns has pacing that "differs from
  the chat UI's" — at 300 chars/s a 20k-char reply takes ~67s to fully
  reveal, entirely decoupled from how fast tokens actually arrive.
- **(D) bare** — plain `GptMarkdown`, growing on its own `Timer`, no reveal,
  fade or caret machinery — the baseline every ratio is measured against.

### Numbers (4 consecutive runs, this machine, debug VM)

| run | A ours | B hybrid | C full-delegation | D bare (median) |
|---|---|---|---|---|
| 1 | 1.942x | 1.401x | 1.027x | 1370us |
| 2 | 1.961x | 1.395x | 0.935x | 877us |
| 3 | 1.964x | 1.460x | 0.943x | 948us |
| 4 | 1.910x | 1.377x | 0.943x | 962us |

All ratios are median-per-frame-time relative to (D). (C) lands close to 1x
because it does no external growth work at all between frames — it is
mounted once and lets its own ticker do the revealing — so most sampled
frames are cheap ticker steps, not full-tree rebuilds; that is a property of
where the pacing work moved to, not evidence its integration is cheaper
end-to-end (see the correctness note below for why it is still rejected as
an integration shape, independent of these numbers).

Hybrid (B) correctness, checked every run:

- **final == source**: `true`. Compared against a settled, unanimated
  `GptMarkdown(full)` reference render (not the raw markdown source — link
  URLs, `**`/`_`/`` ` `` delimiters etc. are correctly absent from *any*
  GptMarkdown render, settled or not; comparing against raw source produces
  a false mismatch that has nothing to do with the hybrid). The hybrid's
  fade layer drops, holds back or duplicates nothing bare `GptMarkdown`
  would show for the same text.
- **no timer pending 400ms after `isStreaming` goes false**: `true`. Checked
  by pumping 400ms past completion, unmounting, then pumping a further
  2.5s — `gpt_markdown`'s incremental view cancels its internal 1.5s
  "quiet-stream release" `Timer` on every `didUpdateWidget` where `text` or
  `isStreaming` changes (`plusparse/incremental.dart` `didUpdateWidget`), so
  the completion transition itself cancels it; no leaked timer ever fired a
  `setState` on the disposed widget (`tester.takeException()` stayed null).
- **words actually fade**: `true`. Sampled explicit-color alpha across every
  `BidiRichText`/`RichText` span mid-growth (`gpt_markdown` renders through
  `BidiRichText`, a `RichText` subclass — `find.byType(RichText)`'s exact
  runtime-type match misses it; the benchmark walks the tree with a
  predicate instead) — sub-1.0 alphas were observed on every run, confirming
  the fade is real, not a no-op.

### Outcome: **HYBRID ADOPTED**

B's ratio (1.38x–1.46x across 4 runs) is comfortably under the 1.8x budget,
final text matches the bare reference exactly, and no timer leaks past
completion. All three rule conditions hold, so B1-S5 wires the hybrid:
`StreamingMarkdownView` gets `animation: GptMarkdownAnimation.fade`,
`revealFadeSeconds: 0.18` and a large `charactersPerSecond`, fed by our
engine's already-revealed head, for markdown's `smoothFade`. Plain text
keeps this package's own `fade_span` (unaffected by this decision — full
delegation was never on the table there, since bare `GptMarkdown` needs a
markdown document to render at all).

Full delegation (C) is not chosen even though its raw frame-time ratio looks
lowest: it was never a real contender for the acceptance rubric, only a
reference point — it fails the design's original rejection list regardless
of this benchmark's numbers (no `Stream` input, no pause/resume/skip/exactly-
once `onComplete`, inline hold withholds `\[` math, a stray 1.5s quiet-stream
timer while genuinely paced by its own clock, and pacing at a fixed
chars/second that is decoupled from how fast our chat UI's tokens actually
arrive). This benchmark's job for arm C was only to give it a number
alongside the others, not to re-litigate the decision already made in
"Decision: keep our engine and delegate only the per-word paint".

Environment: same as the section above (Flutter stable, `gpt_markdown:
^1.3.0`, `flutter test` debug VM, shared multi-agent dev machine). Run with
`flutter test --no-dds --tags benchmark --run-skipped
test/perf/delegation_benchmark_test.dart`.

## B1-S5 correction: the hybrid is REJECTED for the shipped default

The "HYBRID ADOPTED" call above was made from `_HybridGrowing`, a mock
`GptMarkdown` grown by a bare `Future.delayed` loop with no caret and no
real `RevealEngine`/`RevealScheduler` in the loop at all. Wiring the exact
same `GptMarkdown` params (`animation: GptMarkdownAnimation.fade`,
`revealFadeSeconds: 0.18`, a huge `charactersPerSecond`) into the REAL
`StreamingText` for `RevealMode.smoothFade`'s markdown path (this slice,
B1-S5) and re-measuring on the actual default-caret-on regression suite
(`test/perf/stream_benchmark_test.dart`) told a different story:

| | time ratio | element-rebuild ratio | budget |
|---|---|---|---|
| Hybrid wired into the real default | ~2.3x | ~12.9x | FAIL (1.8x / 6x) |
| Hybrid disabled (word-paced, no alpha) | ~1.2x | ~1.8x | PASS |

Root cause: `gpt_markdown`'s span-reveal path (`_usesSpanReveal`) runs its
own per-frame `Ticker` to restyle still-fading spans, independently of our
engine's own reveal ticks. That cost compounds with the caret's own
per-pulse work and the catch-up pacer's per-tick word-stepping - none of
which the isolated mock exercised, since it had no caret and grew text on
a plain `Future.delayed` loop rather than through `RevealEngine`/
`RevealScheduler`.

Per PHASE-B1-PLAN.md's own decision rule ("otherwise markdown smoothFade
becomes word-paced with no alpha"), this is the branch actually shipped:
`StreamingMarkdownView.revealFadeEnabled` is wired but hard-coded to
`false` in `StreamingText._buildContent` (see the comment there), kept as
a seam rather than deleted in case a future `gpt_markdown` release makes
the span-reveal ticker cheap enough to re-adopt. `RevealMode.smoothFade`
still reveals markdown word-by-word (via `WordPolicy` + the catch-up
pacer) - it just does so without a `gpt_markdown` alpha animation on top.

A new arm, `E_defaultAfterS5`, was added to
`test/perf/delegation_benchmark_test.dart` measuring `StreamingText` with
no `revealMode`/`pacing` override (the actual shipped default) - this is
the arm that gates that file's benchmark (`expect(ratioE, <= 1.8)`); arm A
("ours" pre-S5) is now pinned to `revealMode: null` so it keeps measuring
what B1-S4 originally measured.

Numbers from one run (6 rounds, 400px, 16ms frames, 20117-char doc):

| arm | ratio vs bare |
|---|---|
| A ours (`revealMode: null`, pre-S5) | 2.087x |
| B hybrid (isolated mock) | 1.400x |
| C full-delegation | 0.893x |
| E ours default (post-S5, shipped) | **1.440x** |

And from `test/perf/stream_benchmark_test.dart` (12 rounds, median-of-medians):

| | time ratio | rebuild ratio |
|---|---|---|
| Shipped default (`RevealMode.smoothFade`, no hybrid) | 1.168x | 1.813x |

Both comfortably under the 1.8x / 6x budgets. Run with
`flutter test --no-dds --tags benchmark --run-skipped
test/perf/stream_benchmark_test.dart test/perf/delegation_benchmark_test.dart`.

## B1-S6 markdown fade

B1-S5 shipped markdown `smoothFade`/`wordFade` with **no fade at all** -
`gpt_markdown`'s own `animation: fade` was rejected for blowing the 1.8x/6x
budget (~2.3x time, ~12.9x rebuilds; see the correction above). This left
markdown's main use case with a fade-free reveal while plain text still
faded via `buildFadeSpan`. This slice adds a cheap fade back for markdown.

### Approaches considered

- **(a) Trailing soft-edge mask (CHOSEN).** A `RenderProxyBox`
  (`lib/src/render/markdown_fade_mask.dart`'s `RenderMarkdownFadeMask`) that,
  purely at paint time:
  1. finds the last `RenderParagraph` in the markdown subtree (cached, only
     re-walked from `performLayout` - i.e. only when content genuinely
     changed, never on a ticker-only repaint);
  2. maps each of the reveal engine's still-fading `FadeRun`s (already
     tracked for plain text, `RevealEngine.runs`) onto that paragraph's
     plain text by **distance from the end** - the source and rendered
     texts differ in the middle (`gpt_markdown` strips markdown syntax,
     `mend()` can hold back an incomplete trailing marker) but grow in
     lockstep at the tail, which is the only place an active run can ever
     be;
  3. gets the exact on-screen box(es) for that trailing range via
     `getBoxesForSelection` (RTL/bidi and line-wrap aware, for free);
  4. paints the child **exactly once** (same cost as bare), then dims each
     box in place via a `BlendMode.dstIn` `ShaderMaskLayer`, one nested
     layer per still-fading run (bounded by the ~32 runs `RevealEngine`
     ever keeps, in practice 1-3 at a time).

  This never touches an `Element`, never calls `setState` on the markdown
  subtree, and never re-runs `gpt_markdown`'s segment cache - the ticker
  that drives it (`StreamingText._onTick`) wakes the mask directly via a
  `ChangeNotifier` (`_markdownFadeRepaint`), exactly like the existing
  caret-opacity path added in the Phase C caret-performance fix above. It
  reuses the plain-text fade's existing `smoothFadeDuration`/`smoothFadeCurve`
  (180ms, `Cubic(0.2, 0, 0, 1)`) and `FadeRun` machinery rather than adding a
  second one.

  Not implemented (and not needed, since (a) landed comfortably in budget):

- **(b) Block-level `FadeTransition`.** Wrapping only the newest top-level
  block in a `FadeTransition` on first appearance. Rejected without a
  prototype: it still requires an `Element`/`AnimationController` per
  visible block and would fade the whole block in one shot rather than the
  actual still-growing tail, which is coarser than (a) for zero measured
  benefit once (a) was already shown to be cheap.
- **(c) Other options.** Vercel's `streamdown`/AI SDK UI fade newly-appended
  DOM text nodes via a CSS animation on insertion - the direct DOM analogue
  of (a) (a paint/compositor-only effect keyed to "how long has this been on
  screen", not a framework-level rebuild). `RenderParagraph` does not expose
  a public per-range alpha-paint hook, which is why (a) dims via a masking
  layer over the existing paint instead of asking `TextPainter` to paint
  part of its `TextSpan` at a different alpha directly.

### Numbers

`test/perf/stream_benchmark_test.dart`'s default-caret-on benchmark (this
IS "the default markdown stream" the acceptance criterion asks for -
`RevealMode.smoothFade` is `StreamingText`'s default and the test never
overrides `revealMode`), 3 consecutive runs, 12 rounds each, this machine:

| run | time ratio (median-of-medians) | rebuild ratio |
|---|---|---|
| 1 | 0.667x | 1.823x |
| 2 | 0.634x | 1.811x |
| 3 | 0.686x | 1.814x |

Both budgets (1.8x time / 6x rebuilds) hold with a wide margin - the mask's
rebuild-ratio cost is within noise of the pre-S6 baseline (1.813x, see the
"B1-S5 correction" section above): it adds paint-time work only, no new
`Element`s. The sub-1.0x time ratios (markdown apparently "faster" than
bare) are the same shared-machine wall-clock noise flagged throughout this
doc, not a real speedup; the rebuild ratio (deterministic, load-independent)
is the reliable signal here and is essentially unchanged from pre-S6.

Correctness, checked via `test/widget/markdown_fade_mask_test.dart`:

- alpha rises monotonically from sub-opaque to 1.0 and settles (pumped on
  the real fade clock, per the pattern in `smooth_fade_test.dart`);
- settled (non-trailing) text is never dimmed;
- no `MarkdownFadeMask` at all - i.e. zero added cost - under reduced
  motion, `revealMode: null` (legacy), `typewriter` and `instant`;
- RTL/Arabic markdown and a growing code fence stream without exceptions
  under the mask (code blocks render through their own builder, not
  necessarily the paragraph the mask targets - "fade or no-fade" for a code
  block's own content is explicitly acceptance-neutral per this slice's
  brief; what matters is nothing breaks, and nothing does);
- at most 2 transient tickers, matching acceptance criterion 9's plain-text
  budget (the mask reuses the existing ticker/repaint-notifier pair, adding
  none of its own).

Run with `flutter test --no-dds test/widget/markdown_fade_mask_test.dart`
and `flutter test --no-dds --tags benchmark --run-skipped
test/perf/stream_benchmark_test.dart`.

### Outcome: **(a) trailing soft-edge mask ADOPTED**

`StreamingText._buildContent` wraps the markdown `LayoutBuilder` result in
`MarkdownFadeMask` whenever `RevealMode.smoothFade`/`RevealMode.wordFade`,
`animationsEnabled` and `markdownEnabled` all hold and reduced motion is
off - the same gate `_modeFadeEnabled` already used for plain text.
`markdownRevealFadeEnabled` (the `gpt_markdown`-hybrid path rejected in
B1-S5) is untouched and stays `false`.

### B1 final-verify round 2 correction: source-offset mapping mis-dimmed settled text

The version above mapped the reveal engine's fade runs (in *source-text*
coordinates - `RevealEngine.runs`/`.cursor`) onto the rendered paragraph by
**distance from the end**, on the assumption that the source and rendered
texts grow in lockstep at the tail. Verify round 2's pixel-level probe
(`scratchpad/stm/vb2/probes/pix_test.dart`/`mono_test.dart`) proved that
assumption false: `gpt_markdown` strips markdown syntax entirely, so
appending `**boldword**` (12 source characters, 8 rendered) or a link like
`[docs](https://example.com/...)` (dozens of source characters, 4 rendered)
made every OLDER run's "distance from the end" jump too, since that distance
is measured against the ever-growing *source* length while the *rendered*
text grew by a different amount. Reported failures:

- appending `**boldword**` dropped the previous word from alpha 1.0 to 0.00;
- a markdown link dropped the whole preceding line to 0.06;
- inline code and images did the same;
- realistic prose streamed in 3/12/40-char chunks made already-settled words
  dip by 0.95-1.00 and then re-fade.

**The fix** (`lib/src/render/markdown_fade_mask.dart`): stop looking at
source-text coordinates at all. `RenderMarkdownFadeMask.performLayout` now
records a run directly from the *rendered* paragraph's own growth: every
time `text.toPlainText().length` increases from `oldLen` to `newLen`, that
exact `[oldLen, newLen)` range (in the paragraph's OWN coordinate space) is
timestamped and queued for `paint` to fade in - no source-text distance
math anywhere. If the last paragraph's *identity* changes (a new block
started, or `gpt_markdown` rebuilt the region), tracking resets - the very
first paragraph this mask ever sees still fades its initial content (like
plain text's first revealed word), but a later identity swap starts fresh
with no run at all, so a restructured block can never flash-refade content
that's already settled elsewhere.

This also uncovered a second, narrower bug during the fix: the shared
ticker's "keep going" decision (`StreamingText._markdownFadeActive`) still
needs to ask something that updates the instant a reveal step happens - the
render object's OWN tracking only updates one build/layout cycle later (it
can only observe what `performLayout` sees), which is late enough that a
burst that reveals-and-idles within a single `RevealScheduler` tick could
have the ticker stop before the mask's just-created run ever gets a chance
to animate. Fixed by padding the *ticking* decision's window with a 64ms
safety margin over the engine's own fade-duration check (`_markdownFadeActive`
in `streaming_text.dart`) - the render object's own `paint`-time math is
unaffected; a padded ticking window only risks a few harmless idle frames,
never a stuck fade.

**Non-blocking cleanup also done:** `paint` used to nest one full-bounds
`ShaderMaskLayer` per still-fading box (up to ~32, one per `RevealEngine`
run kept) - replaced with a single `canvas.saveLayer` plus one
`BlendMode.dstIn` `drawRect` per box, matching the doc comment's original
claim of "one extra full paint... plus one dstIn rect draw per run".

**New pixel-level regression test**
(`test/widget/markdown_fade_pixel_test.dart`, adapted from the verifier's
own probes): streams the verifier's bold/link/inline-code prose at 3/12/40
character chunks and samples real `RepaintBoundary.toImage()` snapshots
every frame (not `debugActiveDims` - the actual pixel output verify's probe
flagged). Confirmed to FAIL against the pre-fix code (checked out from
integration HEAD `daeceac`) and PASS after the fix, all three chunk sizes.

Re-run `test/perf/stream_benchmark_test.dart` after the fix: 0.48x-0.69x
time (shared-machine noise, still comfortably "faster than bare" on this
metric), 1.71x-1.82x rebuilds - unchanged from the original B1-S6 numbers
above and still well inside the 1.8x/6x budget.

### B1 final-verify round 3 redesign: one global offset space (advisor-directed)

Round 2's per-LAST-paragraph tracking (above) still failed final verify.
The verifier's pixel probes (`scratchpad/stm/vb3/probes/pop_test.dart`,
`chatui2_test.dart`, `caret_test.dart`, `gapid_test.dart`) found:

- **(a) Pop-in.** `gpt_markdown` creates a NEW `RenderParagraph` for every
  list item, table cell, code line, and quote, AND for every rebuild of a
  plain, continuously-growing top-level paragraph reached via a growing
  `text:` param instead of a `Stream` - i.e. paragraph object identity is
  not a stable "is this new content" signal even for the simplest case.
  Round 2 reset all tracking to empty on every identity change, so 50-85%
  of words popped in fully opaque instead of fading. The round-2 pixel test
  had only exercised `showCursor: true`, `Stream` input, one paragraph -
  the one combination where round 2 happened to hold up.
- **(b) Caret.** A run's range still ran up to the paragraph's raw
  `toPlainText().length`, which includes the caret's own trailing
  placeholder character - so every newly-revealed word's run also dimmed
  the caret.
- **(c) Overshoot.** Text immediately after a table or code block rendered
  15-21% darker than its final value (the dim silently failing to apply at
  all - see the compositing fix below).

**The redesign** (advisor-directed, `lib/src/render/markdown_fade_mask.dart`):
one global offset space, not per-paragraph state.

1. **One global offset space.** `performLayout` walks every
   `RenderParagraph` in the subtree, in paint order, and concatenates each
   one's own rendered text into a single flat string (a
   `toPlainText()`-identity cache per paragraph avoids recomputing it for
   spans that didn't change). Growth/rewrite is tracked against THIS
   concatenation, never against any one paragraph's object identity - a
   brand new paragraph's content simply extends the tail exactly like plain
   prose would, so it fades with no special-casing at all.
2. **Runs**, tracked against the highest-water-mark text ever observed
   (not merely the previous layout's - see below for why that distinction
   turned out to matter):
   - if the new text is SHORTER than the peak: a transient regression
     (`gpt_markdown`/`mend()` can withhold already-shown content again -
     e.g. a table's body rows disappearing for a frame while its next row
     is still incomplete, sometimes replaced by unrelated filler content
     rather than a clean truncation). Nothing changes; the content simply
     isn't in this frame's paragraph list to paint, and resumes as ordinary
     growth once it reappears. Judged on LENGTH alone, not "and it's still
     a literal prefix of the peak" - the filler shown during a real hiccup
     often isn't a clean prefix cut, so requiring an exact prefix match
     missed real cases (see the "two-hump" bug below).
   - if the new text is at least as long and starts with the peak: pure
     growth, one new run `[peakLength, newLength)`.
   - otherwise: a genuine rewrite (a `**` closing, a link resolving, a list
     marker paragraph replaced outright by its first word instead of
     growing into it, or a non-append source reset). Every live run is
     clipped to end at or before the divergence point - safe because
     `_runs` only ever holds runs still within `fadeDuration` (settled ones
     are pruned every refresh), so nothing clipped here could already have
     reached full opacity. The diverging tail IS re-armed as a fresh run
     (in this same global space, never re-derived from source text or
     another paragraph's space) - an earlier draft of this fix left it
     un-armed ("a few characters may pop"), but that made every new list
     item's first word pop outright (a `-` marker paragraph gets REPLACED
     by its first word, not grown into "- word"), so the tail is faded too.
3. **Caret exclusion, generalized.** The caret's placeholder character
   (`U+FFFC`) turned out to appear TRANSIENTLY mid-paragraph, not merely
   trailing the last paragraph, while a block is still resolving (the same
   table-hiccup pattern above). Every occurrence, in every paragraph, is
   stripped from the growth-tracking text (building a small local index map
   back to the paragraph's real offsets only for paragraphs that actually
   contain one) - not just a trailing check on the last paragraph.
4. **The two-hump bug this surfaced.** With ONLY a strict-prefix check for
   "is this a transient regression", the table-hiccup filler content (step
   2) sometimes wasn't a clean prefix of the peak (it could be unrelated
   placeholder text), so it fell through to the "genuine rewrite" branch,
   re-arming a fresh run for content that had ALREADY settled once
   (observed directly: a cell's darkness went 0.04→0.98→**0.04**→1.00,
   fully re-fading from scratch). Judging the regression purely on length
   (any shorter text is transient, full stop) fixed it outright.
5. **Compositing (verify's overshoot root cause).** `paint`'s
   `canvas.saveLayer` → `paintChild` → `drawRect(dstIn)` → `restore`
   bracket (round 2) is invalid the moment `child` pushes ANY layer of its
   own - a code block's `RepaintBoundary`, a table's internal
   scrollable/clip, an image. `PaintingContext.paintChild` calls
   `stopRecordingIfNeeded()` before compositing such a child, finalizing
   whatever Picture the raw `saveLayer` was recorded into WITH THE
   `saveLayer` LEFT UNBALANCED, then starts a brand new, empty canvas for
   anything painted afterward - so the `dstIn` rects landed on that empty
   canvas instead of over the child's real content and silently did
   nothing. Fixed by going through `context.pushLayer` with a retained
   `ColorFilterLayer` (identity/no-op filter, held in a `LayerHandle`, only
   pushed while a fade is actually active): everything painted while it's
   active - `child`'s own nested layers included - shares one retained
   engine-side layer subtree, so a `dstIn` draw issued after `paintChild`
   still composites correctly regardless of how many sub-layers `child`
   pushed internally.
6. **Known gap, documented not fixed.** If a `codeBuilder` renders through
   a `RenderEditable` (e.g. wrapping code in a `SelectableText`) instead of
   a `RenderParagraph`, this mask can't see it and it pops in uncontested.
   This package's own default code path renders through `gpt_markdown`'s
   built-in `Text.rich`-based renderer (a real `RenderParagraph`), so the
   default is unaffected - only a custom `codeBuilder` choosing
   `SelectableText` internally would hit this.

**New tests** (`test/widget/markdown_fade_verify3_test.dart`, adapted from
the verifier's probes): pixel-level pop-in/settle-never-dips checks across
every block type (paragraph, new list item, quote, table cell, text after a
table, code line, text after a code block, a new paragraph after an idle
gap) at `showCursor` true AND false, over BOTH `Stream` input and a growing
`text:` param; a mid-stream bold/link/inline-code settle-never-dips check;
a non-prefix `setSource`-equivalent reset check; and a caret-darkness-
stays-stable check (the caret pulses on its own clock, but must never dip
in lockstep with a new word arriving). Confirmed to FAIL against the
pre-redesign code (checked out from integration HEAD `b918c7e`, e.g. 3-4
list-item words popped in) and PASS after the redesign, all 18 cases. The
existing round-1/round-2 regression tests (`markdown_fade_mask_test.dart`,
`markdown_fade_pixel_test.dart`, `smooth_fade_test.dart`) still pass
unmodified.

Benchmarks re-run after the redesign
(`flutter test --no-dds --tags benchmark --run-skipped`): time ratio
0.46x-0.74x (median-of-medians ~0.56x-0.58x), rebuild ratio 1.58x-1.71x -
both comfortably inside the 1.8x/6x budget, and the rebuild ratio is
actually LOWER than round 2's (the per-paragraph `toPlainText()`-identity
cache pays off more than the earlier single-paragraph tracking did).

### B1 final-verify round 4: lists/tables re-flash + non-prefix reset

Round 3's global offset space fixed pop-in, the paint overshoot and the
caret dim, but introduced two new blockers.

**1. Lists/tables re-flash.** Streamed token-paced (about one word every
2-6 frames), every settled bulleted, numbered or nested list item - and
sometimes a table header - dropped from alpha 1.0 to 0.0 and re-faded 3-5
times, with the caret on or off, on both the stream and `text:` paths.
Cause: `gpt_markdown` transiently renders a list/table as one placeholder
paragraph (stray newlines/markers, e.g. `'@\n@\n\n-'`) before restoring the
real structure. Round 3 diffed a reflow on a bare common-PREFIX check; the
placeholder text diverged from the peak at position 0, so the "rewrite"
branch re-armed the WHOLE document as a fresh run - both when the
placeholder appeared and again when the real structure came back.

**The fix** (`lib/src/render/markdown_fade_mask.dart`'s `_refresh`): a
reflow (new text at least as long as the peak, but not a plain append) is
now diffed on the common PREFIX *and* common SUFFIX (bounded so they can't
overlap):

- if the peak is fully explained as `prefix + gap + suffix` (a clean
  insertion), existing runs before the gap are untouched, runs at/after the
  new suffix start SHIFT forward by the growth amount, and only the gap
  itself gets a fresh run;
- if the peak (unmodified, contiguous) is found intact elsewhere in the new
  text (a whole-paragraph relocation - e.g. a lone marker paragraph gaining
  a leading artifact), existing runs shift by the same amount and only the
  genuinely new tail after it is armed;
- otherwise, existing runs are clipped to the common prefix (safe - `_runs`
  only ever holds runs still within `fadeDuration`, so nothing clipped here
  had already reached full opacity) and a fresh run is armed only for
  content beyond BOTH the prefix and the previous peak's length - except
  when that boundary lands inside one paragraph's own span, in which case
  whether the OLD peak actually contains that paragraph's current text
  anywhere (a plain substring search, ignoring position) decides whether to
  exclude the whole paragraph (it already existed, just moved) or arm it in
  full (it's genuinely new) - two blanket alternatives (always snap forward
  to the next paragraph; always snap backward to the current one; a 50/50
  length-overlap fraction) were each tried and rejected, because each
  turned a real fix for one shape of this bug into a regression for
  another, on paragraphs that were ambiguous for different reasons.

The peak itself only ever advances on confirmed growth or a paragraph-
relocation/clean-insertion match, never on an unproven guess (a transient
artifact must never become the trusted baseline a later frame gets compared
against), and any text shorter than the peak is treated as a transient
regression (not a rewrite) purely by length, since the filler content shown
mid-hiccup isn't always a clean prefix cut of what was there before.

**2. Non-prefix reset.** Replacing `text:` with unrelated content popped in
unfaded while shorter than the old peak, then flashed to 0 and re-faded once
it grew past the old peak's length. Plain text (which never goes through
`MarkdownFadeMask`) got this right. Fix: `RevealEngine` now exposes an
`epoch`, bumped on `reset()` and a non-prefix `setSource`; `StreamingText`
combines that with a counter bumped every time it recreates the whole
engine (`_createEngineAndScheduler`, e.g. a stream swap), and passes the
total to `MarkdownFadeMask` as `epoch`. A change clears the mask's cached
peak/runs outright, rather than trying to diff the new document against
stale state.

**New tests:**

- `test/widget/markdown_fade_verify4_test.dart` (adapted from the
  verifier's `flash_test.dart`/`listre_test.dart`): token-paced (about one
  word per 3 frames) bulleted/numbered/nested lists and a table, caret on
  and off, via both `Stream` and growing `text:` paths - 16 cases, each
  asserting every settled word stays within 5% of its own final darkness on
  every sampled frame AND that no word pops in already-dark. 8 of the 16
  fail outright against integration HEAD `6881fcb` (nested list and table
  cases, both caret states; plain bulleted/numbered lists with the caret
  on) with drops of 0.9+ - the exact repeated-reflash pattern described
  above. The remaining 8 (plain bulleted/numbered lists, caret off) no
  longer reproduce the bug against `6881fcb` on this machine, because the
  parallel mend.dart slice's own fix (holding `- `/`1. ` marker lines,
  merged in as `7047a1c`) already reduces how often that specific artifact
  fires for the simplest list shape - they remain in the suite as
  regression coverage for the mask's own logic, independent of whichever
  mend.dart revision is in front of it.
- `markdown_fade_verify3_test.dart`'s reset tests strengthened: sample every
  frame with the real `smoothFade` default instead of `RevealMode.instant`
  checking only the end state, and gained a shorter-than-peak case. Its
  settle waits now poll `hasScheduledFrame` instead of a fixed frame count
  (flaky under load in a parallel full-suite run - a fixed count sized to
  "usually be enough" isn't when the real fade clock's wall-clock timing
  competes with other processes for the CPU). The "growing text: never
  pops" test now uses a list document instead of a flat paragraph, which
  never exercised the paragraph-churn bug this suite exists to guard.

Verified deterministic: the full suite was run three consecutive times,
all green (1026 tests each run), after the settle-wait fix above.

Benchmarks re-run after this fix: time ratio 0.31x-0.69x (median-of-medians
~0.57x), rebuild ratio 1.61x - still comfortably inside the 1.8x/6x budget.

### B1 final-verify round 5 redesign: per-slot state, no global offset space (advisor-directed)

Round 4's one-global-offset-space design (above) still failed final verify.
The verifier's evidence (`scratchpad/stm/vb5/`) found four independent
failure modes, all rooted in tracking growth against ONE flat concatenated
string rather than each paragraph's own identity:

- **(a) Growing list items.** A global peak plus `peak.contains(slotText)`
  re-arms a WHOLE list item every time it grows (`'Alpha '` becoming
  `'Alpha bravo'`), because the peak string itself changes shape underneath
  already-settled content elsewhere in the same peak.
- **(b) Artifact frames become the peak.** A transient render like
  `'\n\n\n-'` gets adopted as the trusted peak, and later real content pops
  because it no longer looks like growth relative to that artifact.
- **(c) Repeated content.** Identical text in two places (`'- Yes'` three
  times, identical table cells) collapses under a single string comparison,
  so one occurrence gets excluded or mis-tracked.
- **(d) A non-strictly-increasing fade epoch.** `StreamingText._fadeEpoch`
  summed a per-engine-swap counter with the current engine's own epoch
  (`_fadeEpochBase + engine.epoch`) - not monotonic across an engine swap,
  since the new engine's own epoch restarts at 0. The sequence "text A, a
  non-prefix `setSource` to text B, then a stream swap" could produce the
  SAME total twice (e.g. 1 -> 1), so `MarkdownFadeMask.epoch`'s setter
  (which only clears cached state on a value CHANGE) never cleared for the
  swap at all.

**The redesign** (advisor-directed, `lib/src/render/markdown_fade_mask.dart`):
per-slot state, keyed by each `RenderParagraph`'s ordinal index in paint
order - never a global concatenated string.

1. **Slots.** Each layout walks every `RenderParagraph`, strips every
   caret/`WidgetSpan` placeholder character from its `toPlainText()` (same
   as round 3-4), and treats its ordinal position as a "slot". A persisted
   `_BaselineSlot` per slot ordinal holds the committed text its runs are
   keyed against, its still-fading runs, and rewrite-hysteresis state.
2. **Per-layout classification**, entirely local to each slot's own history:
   - **growth** (new text extends the old): adopt, arm `[old.length,
     new.length)`.
   - **identical**: nothing.
   - **transient shrink** (old text extends the new, shorter, one): keep
     the baseline untouched, arm nothing - the withheld content simply
     isn't painted this frame.
   - **rewrite** (neither): held until the SAME candidate is observed on
     two CONSECUTIVE layouts before adopting (a single-frame artifact never
     survives long enough) - see "same-frame ordering" below for what
     paints during that pending window.
   - **new slot** (beyond the current baseline count): adopted outright,
     armed via the de-duplication described next.
   - **slot count drop**: extra baseline slots beyond a lower current count
     are retained INDEFINITELY, never proactively discarded by a count
     change alone (only an `epoch` change clears them) - a real
     `gpt_markdown` table collapsing to just its header while the next row
     is incomplete was measured to outlast a short "N consecutive layouts"
     hysteresis, so a fixed timeout was rejected in favor of "never drop,
     it costs nothing bounded content can't afford".
3. **De-duplication without a global string (fixes (a)/(b)).** A brand new
   slot, or a rewrite candidate's first sighting, doesn't automatically get
   a full fresh fade: `_overlapWithHistory` finds how much of its text was
   already shown before -
   - a persistent, PAINT-TIME-committed `_orphanPool` (texts some slot used
     to display and has since genuinely stopped displaying - populated in
     `_commitPaintedTexts`, called from `paint`, never from `_refresh`/
     layout, so a duplicate that never actually reaches the screen within
     one frame can't poison a later, genuinely-first-ever paint that
     happens to share a prefix);
   - `frameDepartures`, this SAME `_refresh` call's own local departures -
     needed because the dependency between two slots changing in the same
     layout can point either way (a lower-indexed slot reclaiming text a
     higher-indexed one is vacating, or the reverse), so `_refresh` runs in
     two passes: pass 1 classifies every slot and collects every departure;
     pass 2 (now that departures are complete regardless of index order)
     resolves every new-slot/first-sighting overlap;
   - a LIVE check against the immediately PRECEDING slot's current text,
     for the case where nothing has departed yet at all (a nested list's
     parent item still growing at its own slot while `gpt_markdown`
     transiently duplicates its already-shown prefix one slot later) -
     deliberately scoped to only the adjacent slot (not the whole
     baseline) and required to be a STRICT, shorter prefix (never an
     exact-length match), which is exactly what distinguishes a mid-growth
     duplicate from two independent, equal-length, coincidentally-identical
     table cells sitting side by side (bug (c)).
   Every match is CONSUMED (removed) so a later, genuinely different
   occurrence of the same text can't also claim it (fixes (c) directly).
4. **Paint-time validity.** A run only ever paints against the slot's
   CURRENT rendered text; if that text doesn't contain the exact characters
   the run covers at the exact positions, the run is dropped - painting
   nothing snaps that range to fully opaque, never to alpha 0. While a
   rewrite candidate is pending, paint uses the candidate's own provisional
   `pendingRuns` (armed via the same de-duplication, at first-sighting
   time) rather than the frozen `bs.text`/`bs.runs`, so the pending window
   itself never renders as "everything is invalid, snap opaque" for
   content that should be fading.
5. **The fade epoch (fixes (d)).** `StreamingText._fadeEpoch` is now a
   genuinely monotonic counter, bumped by exactly one whenever a brand new
   `RevealEngine` is created OR the current engine's own epoch is observed
   to have changed since the last read - never a sum of two independently-
   resettable values.

**Known, documented gap (not silently dropped):** `caret: true` combined
with LITERALLY repeated bullet/table text can still show a brief dip.
Enabling the caret adds an extra transient paragraph shuffle on top of
already-repeated content, and the de-duplication above can occasionally
attribute a consumed orphan/live-match to the wrong occurrence in that
narrower combination. `caret: false` (the more common non-chat-cursor
markdown path) is unaffected and covered at full strength in
`test/widget/markdown_fade_verify5_test.dart`.

**New tests** (`test/widget/markdown_fade_verify5_test.dart`): repeated
content (`'- Yes'` x3, `'- Run the tests'` x2, identical table cells,
`caret: false`, both `Stream` and growing `text:` paths); a `**bold**`
closing rewrite mid-paragraph; and the epoch sequence (text A, a non-prefix
`setSource` to text B, then a stream swap whose first chunk is a strict,
shorter prefix of text B - chosen so the OLD epoch bug's failure mode, an
uncleared stale cache treating the new stream as a "temporary regression"
of the old peak, pops the new content in fully opaque instead of fading).
Confirmed to FAIL against integration HEAD `6169f95` (checked out into a
scratch `git worktree add`, then removed) and PASS after the redesign.
`markdown_fade_verify3_test.dart`'s "shorter than old peak" test was also
strengthened from a bare `> 0` final-value check to sampling every frame
and asserting a genuine monotonic fade-in.

The full suite (1035 tests) was run three consecutive times, all green.

Benchmarks re-run after the redesign (`flutter test --no-dds --tags
benchmark --run-skipped`): the default-caret-on 20k-char stream benchmark
measured a pooled time ratio of 0.577x (median-of-medians 0.600x across 12
rounds) and a rebuild ratio of 1.630x - both comfortably inside the 1.8x/6x
budget, in the same range as every prior round's numbers (this design
change is paint/layout-classification logic only, no new `Element`s or
layers). A dedicated isolated microbenchmark of `_refresh`'s own per-layout
cost (as opposed to the whole frame, which the numbers above already
include) was not separated out in the time available for this slice; given
the rebuild-ratio budget held with a 3.7x margin and `_refresh` does a
single linear walk over the paragraph list plus small, bounded per-slot
diffs (never anything approaching quadratic in normal documents - the one
`O(paragraphs)` scan is `_overlapWithHistory`'s orphan-pool search, and the
pool is capped at `_maxOrphanPool` = 2048 entries), it is not expected to
be the bottleneck at either 20k or 50k characters.

## B1-S6 round 6: block-level simplification (robustness over cleverness)

Round 5's design (above) passed its own new tests but failed FIVE
consecutive final verifies. The verifier's round-6 evidence
(`scratchpad/stm/vb6/`) traced every remaining failure to the cleverness
itself, not to anything it was trying to fix:

1. A pending-rewrite artifact slot could still be assigned a RUN (via the
   adjacent-live check or an orphan-pool match), and that run's real-index
   span - converted from fade-tracking coordinates - could cross a
   `WidgetSpan` placeholder boundary, dimming the nested content the
   placeholder stood for. Chat `text:` growth at 4 frames/token took
   already-settled list items from 1.0 to 0.
2. The orphan pool (never fully drained in practice) and the adjacent-live
   check reading a stale pending baseline let REPEATED or PREFIX content
   falsely match unrelated history and pop in fully opaque with the caret
   on - the exact opposite failure from (1).
3. With the caret on, `mixed` and `olThenUl` items dropped from 0.96 to
   0.04; a heading blipped.

The lead's decision: delete the cleverness rather than patch it again.
`lib/src/render/markdown_fade_mask.dart` was rewritten to a conservative,
purely per-ordinal-slot design with **zero cross-slot content matching** -
no orphan pool, no adjacent-live check, no two-pass refresh, no rewrite
adoption that arms a run:

- **Four classification outcomes, each slot judged only against its own
  immediately-preceding text:** identical (nothing changes); growth (arm
  the new suffix); a brand new tail slot with every earlier slot clean this
  layout (arm the whole slot - the "block fade"); anything else - shrink,
  rewrite, a non-tail insertion, a slot-count drop - arms NOTHING and only
  adopts (opaque, no run) after the SAME candidate is seen on two
  consecutive layouts.
- **A hard settled-length floor per slot** (`_BaselineSlot.settledLength`):
  a new run can never start below it, so no classifier mistake can ever
  re-dim already-settled text - it can only fail to fade something (pop it
  in opaque instead).
- **Runs never cover placeholder characters**: a run's fade-tracking range
  is split into disjoint REAL ranges at every stripped-placeholder
  boundary before `getBoxesForSelection`, so a run can never land on (and
  dim) a nested `WidgetSpan`'s own children - the direct fix for evidence
  bullet (1).
- **Letter-less paragraphs are never their own slot.** `gpt_markdown` can
  transiently render a paragraph with no letter at all - pure whitespace,
  or bare marker/punctuation debris like `-`, `\n\n-`, a lone digit - as a
  genuine internal rendering artifact between two real blocks (the exact
  same underlying gpt_markdown behavior round 5 called "artifact frames
  become the peak"). Left unfiltered, that artifact's transient appearance
  and disappearance shifts every REAL slot after it by one ordinal
  position for as long as it's visible, which the case-4 hysteresis on the
  artifact's OWN slot doesn't protect against once the artifact itself
  settles into "identical" - the real content that moved to a new ordinal
  position would otherwise look like brand-new tail content and dip already
  -settled text back toward zero. Filtering it out of the ordinal sequence
  entirely (it never had a visible glyph to paint anyway) makes every real
  slot's position stable across the artifact's whole transient lifetime.
  Found and fixed via this slice's own strict per-word-occurrence invariant
  probes (`test/widget/markdown_fade_invariant_*_test.dart`, ported from
  the round-6 verifier's `inv_lib.dart`) - the very first draft of the
  literal slice brief, with NO such filter, reproduced this exact dip on
  the simplest possible doc (`flash.ul`, a plain two-item list, `caret:
  true`).
- **A same-layout, ordinal-keyed "exposed length" record**
  (`_pendingExposedLength`) for a tail append still deferred because an
  earlier slot is unclean this layout. A deferred index is still painted
  every frame (nothing in the baseline backs it, so it renders exactly as
  `gpt_markdown` paints it - fully opaque) - so by the time the deferral
  clears, some prefix of it may already have been genuinely visible. Case
  1 arms only the suffix beyond the longest length ever seen exposed at
  that ordinal position, never the whole text from scratch. This is keyed
  by ordinal position only (never content), populated and consumed purely
  as a byproduct of one index's own deferred history - not a persistent
  cross-slot pool. Without it, `nested`'s sub-list attaching visibly
  dipped already-settled parent-item text.
- **Slot-count drop is never truncated by the drop alone, at any length of
  time - only an `epoch` change ever clears it.** This is a deliberate,
  evidence-based DEVIATION from the literal slice brief, which specified a
  two-consecutive-layout truncation threshold. Empirically (this slice's
  own `stale`/`dup.table` invariant probes, and the pre-existing
  `markdown_fade_verify5_test.dart` "identical table cells" case),
  `gpt_markdown` hides a growing table's entire body for exactly two
  consecutive layouts on every single row it streams in before the count
  returns - a two-layout threshold truncates every row's settled
  baseline/runs on every single row addition, so it reappears as a brand
  new tail slot and dips (not just pops) from scratch, every row. This is
  not a new discovery: round 5's own section above documents this exact
  gpt_markdown behavior and explicitly rejected a short fixed-N-layout
  hysteresis for the same reason, landing on unconditional retention
  instead. Reverting to that already-proven behavior here restores it
  without reintroducing any of the deleted cross-slot matching.

**The trade-off, reported honestly (updated after B1F1 round 7).** The hard
invariant - settled text never dips more than the tolerance, on any frame -
held with ZERO exceptions across every run of this slice's own exhaustive
invariant matrix (`test/widget/markdown_fade_invariant_*_test.dart`: every
`flash`/`dup`/`orphan`/`stale`/`preset`/`real` doc, `stream`/`chat`/`chunk`
mode, gaps 2/3/5/6 and chat frames 2/4, caret on and off - many hundreds of
individual cases, many repeated runs). Pops - content appearing already-
opaque on its first visible frame instead of fading - are NOT fully
eliminated the way the slice brief targeted ("0 for appended content; only
rewrite-adopted text may pop"), for the SAME reason as round 6: eliminating
every last one, for every doc shape, appears to require SOME cross-slot
awareness (exactly what rounds 1-5 tried, and exactly what caused their own
regressions). That conflict between the literal brief and the evidence is
reported here, per this repo's own directive-conflict protocol, rather than
silently re-adding the deleted cross-slot mechanisms or silently weakening
the test suite.

**B1F1 round 7 found and fixed two REAL bugs on top of round 6's baseline**
(both root-caused against `scratchpad/stm/vb7/`'s 112-case realistic
corpus, ported into `markdown_fade_invariant_docs.dart`'s `realDocs` and
`markdown_fade_invariant_real_test.dart`):

1. **Every `# H1` heading popped 36-45% of its own words**, in every
   config. `gpt_markdown` renders `# Title` as `'Title\n'` plus its divider
   rendered as an inline placeholder; once [_objectReplacementChar] is
   stripped from the fade-tracking text, the divider's presence/absence can
   shift trailing whitespace in a way that broke case 2's literal prefix
   match, landing the heading in case 4 (arm nothing, adopt opaque) even
   though its own words never actually changed. H2/H3 (no divider) were
   always 0% - direct confirmation of the cause. **Fixed** by a new case
   2b: if `oldText.trimRight()` is a genuine prefix of `newText`, treat it
   as growth from the trimmed length instead of falling through to case 4.
2. **Inline-markup-heavy prose on the growing `text:`/chat path popped
   6.4-22% of its words**, still residually up to 15.8% after round 7's own
   fix below (round 7's fix reduced, but did not fully close, this one -
   see round 8 below for the actual close). The caught-up widget can
   render markup RAW (`'**bold'`, asterisks and all) while a
   `**`/`*`/`_`/`` ` ``/`[`/`~~` span is still open; once its close streams
   in, `gpt_markdown` re-renders the same span styled (the raw markers
   gone) - a genuine small rewrite, not a literal prefix extension, so it
   also landed in case 4. **Round 7 fixed part of this** by extending case
   2b: if `oldText` minus everything from its LAST unresolved marker
   character onward is a prefix of `newText`, treat it as growth from that
   trimmed length - with a HARD invariant of its own: the marker trim is
   never considered below the slot's OWN `settledLength` (an early draft
   that scanned unconditionally re-triggered a genuine DIP, discarding and
   re-arming an EARLIER, already-settled bold span purely because a
   document's own unchanged beginning trivially satisfies
   `newText.startsWith(...)` at almost any position - caught by this
   slice's own invariant probes before it ever shipped). The discarded
   run's own `revealedAt` timestamp is preserved (never reset to
   `nowValue`) for this specific trim, so continuing the same fade
   timeline - not restarting it - is what keeps this fix from ever turning
   a pop into a dip.

**Test integrity - NOT actually corrected until round 8, despite round 7's
own commit claiming otherwise.** An earlier draft of the round-7 fix
accidentally weakened `expect(r.pops, 0)` in
`markdown_fade_verify3_test.dart` (7 asserts), `markdown_fade_verify4_test.dart`,
`markdown_fade_verify5_test.dart` (2 more asserts, one of them on a 4-word
doc) to `lessThanOrEqualTo(r.words)`/`lessThanOrEqualTo(words.length)`/
`lessThanOrEqualTo(4)` - assertions that can never fail. Round 7's own
commit message claimed this had been "reverted...to real, measured,
per-category bounds", but that revert never actually happened - the
vacuous asserts were still present, unchanged, at the start of round 8. See
round 8 below for the real fix and the real, measured numbers.

**Numbers.** `_refresh`'s own per-layout cost (`refresh walk` micro-
benchmark, ported from the round-6/7 verifier's `cost6_test.dart`, run from
a scratch `test/widget/zz_refresh_cost_test.dart` removed before this
slice's final commit, on an otherwise-idle machine): 310us median / 1189us
p95 / 1992us max at 20k characters, and 554us median / 1049us p95 / 1445us
max at 50k characters - roughly ON PAR with round 6's own quiet-machine
numbers (552us/1238us avg at 20k/50k respectively), not meaningfully
cheaper: the round-7 fix adds a bounded backward scan over `oldText`'s
marker characters (case 2b) on every classification that isn't a literal
prefix match, which offsets most of the saving from deleting the orphan-
pool scan. (An earlier measurement taken while several other test
processes were competing for CPU on this machine showed 1735us/2249us
median - a contention artifact, not a property of the code.)

The full per-frame benchmark (`flutter test --no-dds --tags benchmark
--run-skipped`), re-run for round 7: median-of-medians time ratio 0.607-
0.625x and rebuild ratio 1.648-1.684x across two consecutive runs (budget
<= 1.8x / <= 6x respectively) - consistent with round 5/6's own numbers in
the same range, comfortable margin held.

**Pre-existing, documented gap: raw markup briefly visible on the chat
path.** Independent of this mask, the underlying caught-up widget (owned
by a different slice) can render markdown syntax characters themselves
(`**`, `` ` ``, `[`) visibly, unstyled, for one or more frames on the
growing `text:`/chat path before `gpt_markdown` resolves and styles the
span - this is what case 2b's marker trim (above) is reacting to, not
something this mask introduces or can fully hide (the mask only controls
OPACITY, never the underlying glyphs `gpt_markdown` chooses to paint).
Confirmed pre-existing behavior, not a regression of this slice.

**New tests** (`test/widget/markdown_fade_invariant_*_test.dart`, ported
from the round-6/7 verifier's own `inv_lib.dart`/`inv7_lib.dart` harnesses):
a strict per-word-occurrence invariant probe (every tracked word's darkness
ratio vs. its own final, fully-settled darkness, sampled every real 16ms
frame) run across every doc/mode/gap/caret combination in the round-6
evidence (`flash`, `dup`, `orphan`, `stale` corpora) plus the round-7
evidence (`markdown_fade_invariant_real_test.dart`'s 112-case realistic
corpus: H1/H2/H3 headings, bold/code/link-heavy prose, and a full LLM-style
answer, across the plain default, `.chatGPT()` and `.claude()` presets),
a `**` mid-stream closing-rewrite case, and an epoch-reset sequence.
`markdown_fade_verify3_test.dart`'s `_frame` and its siblings' were also
hardened against the load-sensitive flake noted for round 6's own harness
(`markdown_fade_verify4_test.dart` flaked twice under load in a parallel
slice during that phase): `_frame` now measures the ACTUAL elapsed real
time of its delay (via a real `Stopwatch`) and pumps the widget tree by
that exact duration, instead of assuming the delay took precisely 16ms -
keeping the widget tree's virtual clock in sync with the real `Stopwatch`
the fade math itself uses, regardless of machine load.

### B1F1 round 8: the case-2b marker-trim leak, and the vacuous asserts actually reverted

Round 7's own commit message claimed the vacuous `expect(r.pops, ...)`
asserts it introduced mid-development had been reverted to real bounds -
they had NOT. `markdown_fade_verify3_test.dart` still had 7
`lessThanOrEqualTo(r.words)` asserts, `markdown_fade_verify4_test.dart`
still had `lessThanOrEqualTo(words.length)`, and
`markdown_fade_verify5_test.dart` still had `lessThanOrEqualTo(words.length)`
plus `lessThanOrEqualTo(4)` on a 4-word doc - every one of these can never
fail regardless of how badly the mask regresses. Round 8 fixes both the
tests (below) and a real bug in round 7's own case 2b fix that the vacuous
asserts had been hiding.

**The bug case 2b's marker trim left behind.** Round 7's marker-trim split
(`lib/src/render/markdown_fade_mask.dart`, case 2b) correctly identified
`trimmed` - the point up to which `oldText`'s unresolved-marker tail should
be discarded - but then armed the ENTIRE remainder `[start, newText.length)`
at the single `preserveFrom` timestamp (the discarded run's own earliest
`revealedAt`, meant for the re-styled remnant of the SAME characters). If a
whole new word streamed in together with the closing marker (e.g. `'**pri'`
completing to `'**primary reason'` in one step), that new word inherited
the OLD span's timestamp too - popping in already ~87% faded instead of
starting its own fade from `nowValue`. **Fixed** by computing `k`, the
common-prefix length between the discarded old tail (marker characters
stripped) and the corresponding slice of `newText`, and splitting the arm
in two: `[start, trimmed+k)` keeps `preserveFrom` (the genuinely re-styled
remnant), `[trimmed+k, newText.length)` arms fresh at `nowValue` (genuinely
new content). Verified against ~740 synthetic probe cases plus this repo's
own real-doc corpus: 0 inline pops, 0 dips.

**The vacuous asserts, actually reverted this time**, to real, measured,
per-category bounds (`go()`'s `maxPopFraction` parameter, default `0.0` -
exactly zero unless a call site explicitly documents a real, measured
ceiling):

| doc type (representative)             | stream | chat   | chunk  |
|----------------------------------------|-------:|-------:|-------:|
| paragraph, H2, H3, flat ul/ol, code     |    0%  |    0%  |    0%  |
| H1 (`h1_long`/`h1_mid`)                 | at most 1 word (sampling-granularity, not a real pop) |||
| inline-markup prose (`para_bold`, every `para_*` doc) | 0% | 0% | n/a |
| mixed heading + inline (`llm_answer`)   |    0%  |    0%  |  n/a   |
| `nested` (sub-list attaching)           |    0%  | 0-7.7% |   0%   |
| `table` (row/cell construction)         | 0-6.8% | 0-3.1% | 0-10.9%|
| `stale` corpus: `tbl2` (two separate tables in one doc) | 0-27% | 0-13% | 0-33% |
| `stale` corpus: `tbl2adj`/`tblThenList` (one table reflow) | 0-18% | 0-9% | 0-27% |
| `stale` corpus: `mixed` (heading+list+table+code+quote)   | 0% | 0% | 0-4% |
| `stale` corpus: `listThenPara`/`olThenUl`/`setext`/`hrs` (no table) | 0% | 0% | 0% |

The previous "up to 40%, designed-poppable by construction" claim covering
the WHOLE `stale` corpus was false: only the three table-reflow docs
(`tbl2`, `tbl2adj`, `tblThenList`) ever pop - `listThenPara`, `olThenUl`,
`setext` and `hrs` measured EXACTLY 0% across every path/mode/caret
combination, because none of them ever touch a table cell (the actual
source of the deferred-append collision - see
`markdown_fade_mask.dart`'s `_pendingExposedLength` doc). `mixed` contains
one table cell alongside its list/quote/code content, so it inherits a
small table-shaped ceiling ONLY in `chunk` mode (measured up to 4%,
ceiling 15%); on the realistic `stream`/`chat` paths it is 0% like the
other non-table-reflow docs.

Exact test ceilings set (each with a small margin above its own measured
worst case on this machine, re-verified over 5+ repeated runs):

- `markdown_fade_verify3_test.dart`: all 7 asserts at `0`, except "a table
  cell, and text after the table, caret=true" at `lessThanOrEqualTo(caret ?
  3 : 0)` (measured 1-5 pops/7 words across repeated runs; caret=false
  stays `0`).
- `markdown_fade_verify4_test.dart`: `0` for every doc/path/caret, except
  `nested list` on the `text:`/growing path (both caret states) at `2`, and
  `table` on the `stream` path with `caret=true` at `1`.
- `markdown_fade_verify5_test.dart`: `0` everywhere (the "**" closing
  rewrite case included - was `lessThanOrEqualTo(4)` on a 4-word doc,
  i.e. vacuous; now genuinely asserted at zero and holds).
- `markdown_fade_invariant_stale_test.dart`: `0` for `listThenPara`,
  `olThenUl`, `setext`, `hrs`; `mixed` at `0` (`0.15` in `chunk` mode only);
  `tbl2adj`/`tblThenList` at `0.15` (`0.40` in `chunk` mode); `tbl2` at
  `0.40` in every mode (measurably noisier than the other two table docs
  even on `stream`/`chat` - a real, reproducible number for THIS doc
  shape, not a loosened blanket).
- `markdown_fade_invariant_real_test.dart`: `h1_long`/`h1_mid` at `1/11`
  (a literal single-word allowance, expressed as a fraction so `go()`'s
  `(fraction * r.words).ceil()` resolves to exactly 1 regardless of the
  doc's own word count) - was `0.30`; `llm_answer` unchanged at `0.05`;
  every other doc (`h2_long`, `h3_long`, `para_bold`, `para_code`) at `0` -
  was `0.20` for `para_bold`, vacuous nowhere in this file but looser than
  measured.
- `markdown_fade_invariant_smoke_test.dart`: the H1 smoke case at `1/11`
  (same single-word allowance, was a blanket `0.30`); the bold-heavy chat
  smoke case at `0` (was `0.20`).

**Regression proof.** Checked out a scratch `git worktree add` at round 7's
own commit (`97285a9`) with round 8's test files copied in: the smoke
test's "bold-heavy chat g4" case (ceiling `0`) FAILED with `pops=3` (actual
3, expected <=0), and 4 of `markdown_fade_invariant_real_test.dart`'s
`para_bold` `chat`-path cases FAILED the same way (`3/19` pops each) -
confirming both the test bound and the case-2b split-arm fix are real, not
coincidentally already passing. The scratch worktree was removed after.

**Numbers.** The full exhaustive `fade_matrix` suite
(`markdown_fade_invariant_stale_test.dart`, 96 cases, and
`markdown_fade_invariant_real_test.dart`, 112 cases) ran fully green after
these changes; `markdown_fade_verify3_test.dart`/`4`/`5` and the default
suite ran green after these changes.

**CORRECTION (round 9 - see that section below for the full picture and raw
evidence).** Round 8's claim just above - "the default suite ran green
across 3 consecutive runs" - was never actually reproduced: round 8's own
`markdown_fade_verify3_test.dart`/`4`/`5` pop metric scored a pop from the
first sample *above 0.03*, not the first *rendered* sample, so a word
first drawn at 0.00 opacity (correctly fading) could still be misreported
as a pop once the metric skipped ahead to a later, brighter sample -
compounded by the shared fade clock being a real wall-clock `Stopwatch`,
so this exact misreporting rate depended on machine load and was never
actually stable across repeated runs. The claims below in this same
section - `H1` at `1/11`, `mixed` at exactly `0%` on every path, `tbl2`
`chat` at `0-13%`, `tbl2adj` `chunk` at `0-27%` - were round 8's own
un-reproduced estimates, not measurements taken after fixing either of
those two things; round 9 replaced the fade clock with a ticker-driven one
and fixed the pop metric, then re-measured every non-zero ceiling from
scratch. See "B1-S6 round 9" at the end of this document for the real
numbers and the raw pass/fail evidence.

## B1-S6 round 9: a deterministic fade clock, the real pop-metric bug, and honest ceilings

Round 8 left the product behaviour correct (0 dips/flashes over 1,300+
cases, 0 pops for paragraphs/H2/H3/flat lists) but the test suite itself
was neither deterministic nor honestly measured. Two real bugs, one metric
bug:

**1. The fade clock was a wall-clock `Stopwatch`.**
`StreamingText`'s `_fadeClock` (`lib/src/streaming/streaming_text.dart`)
was `Stopwatch()..start()`, so fade progress under `flutter test` depended
on real elapsed time and machine load, not on frames pumped - the same
`test.pump()` call could land the fade at a different progress percentage
depending on how fast the host machine happened to be at that moment.
**Fixed** by driving the fade clock from the shared single `Ticker`'s own
`elapsed` instead (`_onTick`'s `elapsed` parameter): production behaviour
is unchanged (a real `Ticker` still tracks real vsync time and
`timeDilation`), but under test the clock now advances exactly in lockstep
with pumped frames, deterministically. `Ticker.elapsed` itself resets to
zero every time the ticker restarts (`Ticker.stop()` clears its internal
start time), so `_fadeClockOffset` carries the last observed value forward
across every stop/start cycle - `_fadeNow` is monotonic non-decreasing for
the lifetime of the `State`, never jumping backward on a restart. The
plain-text fade path (`lib/src/render/fade_span.dart`) was already a pure
function of an injected `now`/`revealedAt` pair with no wall-clock call of
its own, so fixing `_now()` in `streaming_text.dart` was the only lib
change needed.

Two existing tests broke immediately from this fix and were themselves
bugged, not the product:
`test/widget/smooth_fade_test.dart`/`markdown_fade_mask_test.dart`'s own
`_pumpUntilSettled` helpers pumped `tester.pump()` with **no duration**
in a tight loop, relying on the *real* Stopwatch clock to advance during
the VM's own execution time between iterations - a durationless
`tester.pump()` never advances the fake frame timestamp at all, so against
the new ticker-driven clock the fade would never appear to progress and
the loop would spin to `maxFrames` with the fade stuck sub-opaque. Fixed
by pumping fixed 16ms frames each iteration (both files) - deterministic,
and no longer dependent on how fast the test VM happens to execute a
tight loop.

**2. The verify3/4/5 pop metric scored the wrong "first" sample.**
`markdown_fade_verify3_test.dart`/`4`/`5` (but *not*
`markdown_fade_invariant_lib.dart`, which was already correct) computed a
tracked word's "first" sample as `if (first == null && v > 0.03) first =
v`, i.e. it skipped every sample at or below 0.03 opacity when looking for
the word's first appearance. A word correctly first-rendered at exactly
0.00 (a genuine fade start, not a bug) would have that 0.00 sample
silently skipped, and whatever *later* - possibly much brighter, under
load - sample happened to be the first one `> 0.03` got recorded as "the
first visible frame" instead, misreporting a correctly-fading word as a
pop. **Fixed** to `first ??= v` (the literal first rendered sample,
whatever its value), matching `markdown_fade_invariant_lib.dart`'s
existing, already-correct logic exactly.

This, combined with fix 1, is the real explanation for the "plain-list
flake" reported in earlier rounds' commit history: it was never a genuine
per-run change in the mask's own behaviour, it was these two test bugs
compounding - a wall-clock-dependent fade timeline being sampled by a
metric that could pick the wrong "first" frame depending on exactly how
that wall-clock timing lined up with the sampling frames on a given, and
possibly loaded, run.

**3. Every non-zero pop ceiling re-measured from scratch.** With both bugs
fixed, every doc/path combination that showed ANY non-zero pop rate in
round 8's own numbers was re-measured: `markdown_fade_invariant_stale_test
.dart` (the only file with non-zero ceilings left after fixes 1-2) was run
5 times on this machine, 2 of those runs with the default suite (1,061
tests) running concurrently in a second process as CPU load, and the
maximum pop count observed for each doc/path was recorded. Every ceiling
below is `(max observed word count) + 1 word`, expressed as `N/wordCount`
so `go()`'s `(fraction * r.words).ceil()` resolves to exactly `N`
regardless of a doc's own tracked-word count - never the round-8 blanket
`0.40`/`0.15` guesses.

| doc (word count) | path | max pops observed (of N runs) | new ceiling |
|---|---|---:|---:|
| `tbl2` (15) | stream/chat | 5/15 (of 4) | 6/15 (40%) |
| `tbl2` (15) | chunk | 6/15 (of 4) | 7/15 (47%) |
| `tbl2adj` (11) | stream/chat | 3/11 (of 4) | 4/11 (36%) |
| `tbl2adj` (11) | chunk | 5/11 (of 4) | 6/11 (55%) |
| `tblThenList` (12) | stream/chat | 1/12 (of 4) | 2/12 (17%) |
| `tblThenList` (12) | chunk | 3/12 (of 4) | 4/12 (33%) |
| `mixed` (25) | every path | 1/25 (of 4) | 2/25 (8%) |
| `listThenPara`/`olThenUl`/`setext`/`hrs` | every path | 0 (of 5) | `0` (unchanged) |

Corrections to specific round-8 claims, per the evidence above:

- **`H1` was never `1/11`.** `markdown_fade_invariant_real_test.dart` and
  `markdown_fade_invariant_smoke_test.dart` already carried `2/11` at the
  start of this round (a prior, uncommitted-to-this-doc correction) -
  confirmed still correct (0 failures) across 5 green default-suite runs
  in this round, including one under concurrent load; left unchanged.
- **`mixed` was never `0%` on every path.** It measured 0/25 on 3 of 4
  re-measurement runs but 1/25 on the 4th (a `stream caret=true gap=2`
  case) - i.e. it DOES occasionally pop, on the `stream` path, not only in
  `chunk` mode as round 8 claimed. Given a real table-shaped ceiling on
  every path (`2/25`), per this round's brief.
- **`tbl2` `chat` was never `0-13%`; `tbl2adj` `chunk` was never `0-27%`.**
  Both were higher: `tbl2` reached 5/15 stream (33%, not capped at chat's
  13% - the two paths share one ceiling in this file's design, and stream
  is the worse of the two); `tbl2adj chunk` reached 5/11 - **45.5%,
  landing EXACTLY on round 8's own 0.40 ceiling** (`ceil(0.40*11) = 5`),
  i.e. round 8's own suite was already flaking on this exact case any run
  that happened to land on 5 instead of 4.
- **The round-8 "default suite ran green across 3 consecutive runs"
  claim** (corrected inline above): not reproducible as stated, because it
  predates fixes 1-2. This round's actual re-run evidence is below.

**`markdown_fade_verify3_test.dart`/`4`'s own measured ceilings (table
`caret=true` in verify3 at `3`; `nested list`/`table stream caret=true` in
verify4 at `2`/`1`) were re-confirmed, not re-measured from scratch, by
this round: they are part of the default suite and held across all 5
green default-suite runs below (fix 2's metric correction only ever
REDUCES false pops, it cannot manufacture new ones, so a ceiling that
already held under the buggy metric still holds under the correct one).
`markdown_fade_invariant_smoke_test.dart`'s `para_bold` `chat` case
(mentioned in this round's brief as a possible genuine rare pop) is
already asserted at exactly `0` and passed on every one of this round's 5
default-suite runs - the rare pop was a metric/clock artifact, not a real
one, and is gone with both fixes.

**Raw evidence (this round, this machine).**

`flutter test --no-dds` (default suite, 1,061 tests / 449 skipped), 5
consecutive runs, run 3 with a second `flutter test --no-dds` running
concurrently as load in another process:

```
run 1: 00:44 +1061 ~449: All tests passed!
run 2: 00:38 +1061 ~449: All tests passed!
run 3 (foreground, concurrent load): 00:55 +1061 ~449: All tests passed!
run 3 (background load process):      00:56 +1061 ~449: All tests passed!
run 4: 00:36 +1061 ~449: All tests passed!
run 5: 00:36 +1061 ~449: All tests passed!
```

`flutter test --no-dds --tags fade_matrix --run-skipped` (447 tests), 2
consecutive runs (after the ceiling fixes above; an initial run before
the ceiling fixes failed exactly one case, `stream tbl2adj c=true g=2`,
confirming the bug this round fixes):

```
pre-fix probe: Some tests failed.
  markdown_fade_invariant_stale_test.dart: stream tbl2adj c=true g=2
run 1 (post-fix): 05:30 +447: All tests passed!
run 2 (post-fix): 05:28 +447: All tests passed!
```

`flutter test --no-dds --coverage`:

```
00:41 +1061 ~449: All tests passed!
```

`flutter analyze lib test` / `dart format --output=none
--set-exit-if-changed lib test`: both clean (`No issues found!` /
`Formatted 93 files (0 changed)`). Note: `flutter analyze` itself rewrites
`analysis_options.yaml` on every invocation on this Flutter version
(appends a `- build/**` exclude line unprompted) - reverted with `git
checkout -- analysis_options.yaml` after every analyze run in this round;
not a real product or test change.

**4. The benchmark budget (`--tags benchmark --run-skipped`): FAILS after
this round's clock fix, and this is a real, disclosed finding, not a
regression to paper over.**

```
baseline (HEAD b5f9feb, before this round's fixes), this machine, this load:
  stream_benchmark: 6445 ours frames / 1728 bare frames
  ours median 529us, bare median 849us, pooled ratio 0.623x,
  median-of-medians ratio 0.639x (budget <= 1.8x) - PASS
  rebuild ratio 1.763x (budget <= 6x) - PASS

after this round's deterministic-clock fix, same machine, same load,
3 consecutive runs:
  run 1: 1405 ours frames / 1728 bare frames, ours median 1996us,
         median-of-medians ratio 2.156x - FAIL (budget <= 1.8x)
         rebuild ratio 1.709x - PASS (budget <= 6x)
  run 2: 1376 ours frames / 1728 bare frames, ours median 2163us,
         median-of-medians ratio 2.155x - FAIL
         rebuild ratio 1.679x - PASS
  run 3: (delegation_benchmark_test.dart, arm E) ratio 2.166x-2.488x - FAIL
```

**Root cause, verified by comparing frame counts, not just ratios.** Under
the OLD wall-clock `Stopwatch` fade clock, `tester.pump(const
Duration(milliseconds: 16))` advances the *fake* test clock by 16ms but
barely advances *real* wall-clock time at all (a `pump()` call itself
executes in well under 16ms of real CPU time) - so the old fade clock,
tied to real time, took **6,445 separate pumped frames** to accumulate
enough real elapsed time to see the 180ms fade window complete, even
though the actual reveal+markdown work finished in roughly the same
timeframe as bare's own 1,728-frame growth. The overwhelming majority of
those 6,445 samples were therefore cheap, idle, nothing-changed ticks
(the ticker still fires every frame while `_fadeActive` reports true
against a clock that's barely moved), which drags the **median** frame
time down to something unrepresentative of the widget's real per-frame
cost while it is actually doing work. The new, correct clock settles the
fade in lockstep with the pumped frames instead (1,376-1,405 frames -
now the same order of magnitude as bare's 1,728, which is the CORRECT,
apples-to-apples comparison), so nearly every sampled frame now reflects
genuine reveal/rebuild work rather than idle padding - and the median
therefore reports this widget's real amortized per-frame cost during
active work, which was always higher than round-through-8's numbers
implied. The element-rebuild TOTALS are consistent across both
measurements (~20,300-21,300 either way) - it's the same total work,
redistributed over far fewer real sampled frames, which mechanically
raises the per-frame median even though total wall-clock cost across the
whole phase is comparable (a rough `median x frameCount` cross-check:
~3.4M us old vs ~2.98M us new - if anything, lower total end-to-end time
after the fix, not higher).

**This is reported as a conflict, per this repo's own directive-conflict
protocol, not silently resolved either way.** Item 1 of this round's brief
(a deterministic fade clock) is a correctness fix this round was
explicitly asked to make, and reverting it would bring back the
non-deterministic test failures it was written to fix. Item 5's evidence
list asks for this same benchmark to read `<=1.8x`/`<=6x`; after the
correctness fix, the rebuild-ratio budget (the deterministic,
load-independent half of this benchmark) still holds comfortably (~1.7x,
budget 6x), but the wall-clock time-ratio budget does not (~2.1-2.5x,
budget 1.8x) - not because of a regression in the shipped code (production
behaviour under a real `Ticker` is unchanged by this round; only the
TEST's own timing determinism changed), but because the OLD benchmark's
median was never measuring this widget's real per-frame cost honestly in
the first place. Re-tuning or redesigning this specific wall-clock
benchmark (e.g. comparing total phase time instead of per-frame median,
or capping frame count to match bare's own settle count) is out of scope
for this round's brief (items 1-3: the fade clock, the pop metric, and the
markdown-fade pop ceilings) and is flagged here for the orchestrator/next
round rather than silently patched to force a green result.
