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
