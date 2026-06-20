# Package Audit — `flutter_streaming_text_markdown`

**Version audited:** 1.9.0
**Date:** 2026-06-20
**Scope:** `lib/` source, public API, tests, CI, packaging metadata.

This is a static audit (the environment has no Flutter toolchain, so `flutter
analyze` / `flutter test` were not executed). Findings are ordered by severity.
Line references are against the audited tree.

> **Resolution (v1.10.0):** Findings #1–#5, #7–#9, #11, #12 are addressed in
> v1.10.0, and #6 is partially addressed (the built-in LaTeX path now honors a
> supplied `latexBuilder` and the degradation is documented; the fallback
> renderer itself is unchanged). See `CHANGELOG.md` for details. Because no
> Flutter toolchain is available in this environment, the changes were reviewed
> statically and covered with new tests, but `flutter analyze`/`flutter test`
> must be run in CI (a new `.github/workflows/ci.yml` does this on every PR).

---

## Summary

The package is well-structured for its non-streaming, static-`text` use case
(typing animation, markdown via `gpt_markdown`, RTL/Arabic handling, theming,
shimmer). The most important problems cluster around the **headline v1.9.0
feature — direct `Stream<String>` input** — which does not behave the way the
README, CHANGELOG, and example claim, and has a data-loss interaction with the
default tap-to-complete behavior. There is also a packaging issue (declared
Flutter SDK lower bound is too low for the APIs actually used) and a meaningful
amount of dead API surface.

| # | Severity | Area | One-line |
|---|----------|------|----------|
| 1 | High | Streaming + tap | Tapping mid-stream wipes all received text |
| 2 | High | Streaming | Stream chunks are not animated by typing settings |
| 3 | High | Streaming | Swapping the `stream` object is ignored (stale subscription) |
| 4 | Medium | Packaging | Declared `flutter: ">=3.10.0"` but uses 3.27+ APIs |
| 5 | Medium | Streaming | Controller `progress` never updates for streams |
| 6 | Medium | LaTeX | `latexEnabled` path bypasses gpt_markdown, drops most markdown |
| 7 | Low | API/perf | Dead parameters; cursor controller runs forever but draws nothing |
| 8 | Low | A11y | `semanticsLabel` ignored; no live-region announcement |
| 9 | Low | Docs | `StreamingText` is actually re-exported, contradicting CLAUDE.md |
| 10 | Low | Behavior | Whole-widget `GestureDetector` intercepts link taps by default |
| 11 | Low | Memory | Text-keyed caches grow unbounded over a widget's lifetime |
| 12 | Low | CI | No PR-time analyze/test workflow; `checkout@v3` in publish |

---

## High severity

### 1. Tapping while a stream is in flight erases all received text

`StreamingText.build` (`lib/src/streaming/streaming_text.dart:1298`) wraps the
output in a `GestureDetector` whose `onTap` (active because
`completeAnimationOnTap` defaults to `true`) does:

```dart
_displayedTextBuffer.clear();
_displayedTextBuffer.write(widget.text);   // <-- widget.text is '' for streams
```

For `stream:` usage, `text` defaults to `''` (it is only the *initial* buffer).
So "complete the animation on tap" resolves to **"replace everything streamed so
far with the empty initial buffer."** The shipped example
(`example/lib/sections/streaming_section.dart`) even instructs the user to *"Tap
the text while it streams to see `completeAnimationOnTap` in action"* — doing so
blanks the widget.

**Fix direction:** when `widget.stream != null`, tap-to-complete should be a
no-op (or should simply stop the trailing fade), never reset the buffer to
`widget.text`. At minimum, write back `_displayedText` (what's already shown)
rather than `widget.text`.

### 2. Stream chunks are appended instantly, not animated

CHANGELOG 1.9.0 and README (line ~113) state each chunk is *"appended to the
rendered text and animated using the active typing settings."* The engine does
not do this. In `_handleStream` (`streaming_text.dart:680`):

```dart
if (_isAnimationActive && previousLength > 0) {
  _continueAnimationFrom(previousLength);   // empty no-op (lines 733–742)
} else if (!_isAnimationActive) {
  _startAnimationFrom(previousLength);
}
```

`_isAnimationActive` is set to `true` in `_initializeText` *before*
`_handleStream` runs, so:
- first chunk (`previousLength == 0`): neither branch executes;
- every later chunk: the first branch calls `_continueAnimationFrom`, whose body
  is empty.

The net effect is that the chunk is written to the buffer and `setState`
re-renders it **whole**. `typingSpeed`, `wordByWord`, and `chunkSize` have **no
effect** on streamed content. The only motion is the optional `trailingFade`.
This is a real gap between documented and actual behavior; either implement
per-chunk typing for streams or correct the docs/example to say chunks render as
they arrive and rely on `trailingFadeEnabled` for smoothing.

### 3. Replacing the `stream` does not re-subscribe

`didUpdateWidget` (`streaming_text.dart:342`) only reacts to `text` changes and
config changes; `_hasConfigurationChanged` (line 364) does not include `stream`.
The parent `StreamingTextMarkdown` builds the inner widget with a `ValueKey`
(`flutter_streaming_text_markdown.dart:504`) that encodes `wordByWord`,
`chunkSize`, `typingSpeed`, `latexEnabled` — **but not stream identity**. So if a
consumer swaps in a new `Stream<String>` (e.g. a new LLM response), the widget
keeps listening to the old subscription and silently ignores the new one. The
old subscription is also never cancelled on swap (only on dispose).

**Fix direction:** in `didUpdateWidget`, detect `widget.stream != oldWidget.stream`
and re-run `_streamSubscription?.cancel()` + reset + `_handleStream()`.

---

## Medium severity

### 4. Declared Flutter SDK constraint is lower than the APIs used

`pubspec.yaml` declares `flutter: ">=3.10.0"` and `sdk: '>=3.0.0 <4.0.0'`, but
the code uses APIs introduced much later:

- `Color.withValues(alpha: …)` — `streaming_text.dart:1665,1671` — added in
  Flutter 3.27 / Dart 3.6.
- `ColorScheme.surfaceContainerHighest` — `streaming_text.dart:1664` — added in
  Flutter 3.22 (Material 3 color-role rename).

On Flutter 3.10–3.21 the package will not compile, so the constraint is
inaccurate and pub.dev resolution can mislead consumers. Bump to at least
`flutter: ">=3.27.0"` and `sdk: ">=3.6.0 <4.0.0"` (or replace `withValues` with
`withOpacity` and use a pre-3.22 color role if broad support is desired).

### 5. Controller progress is stuck at 0 for streams

`_updateProgress` (`streaming_text.dart:671`) computes progress only when
`widget.text.isNotEmpty`. With streams `widget.text == ''`, so
`controller.updateProgress` is never called, `progress` stays `0.0`, and
`onProgressChanged` never fires until `markCompleted()` on stream done. The
0.0→1.0 progress contract documented for `StreamingTextController` effectively
does not hold for the streaming use case (where progress matters most). A stream
has no known total length, so consider documenting progress as indeterminate for
streams, or drive a coarse progress signal from chunk counts.

### 6. `latexEnabled` bypasses gpt_markdown and loses most markdown

When `latexEnabled && LaTeXProcessor.containsLaTeX(text)`, `_buildMarkdownBody`
(`streaming_text.dart:1626`) routes to `_buildLatexMarkdown`, which:

- renders LaTeX as **blue monospace text** via `_formatLatexForDisplay`
  (naive `\alpha`→`α` string replacement, lines 1821–1875), not real math; and
- renders the surrounding prose with `_buildFormattedText` (lines 1753–1819),
  which only understands `**bold**` and `*italic*`.

In that mode, headers, lists, links, tables, blockquotes, code blocks, and any
caller-supplied `components` / `codeBuilder` / `linkBuilder` etc. are silently
dropped. Meanwhile `gpt_markdown` already supports LaTeX natively (the widget
even exposes a `latexBuilder` passthrough). The custom LaTeX path is therefore
both lower-fidelity for math and destructive to markdown. Strongly consider
deferring LaTeX to `gpt_markdown` and deleting `_buildLatexMarkdown` /
`_formatLatexForDisplay`, or at minimum documenting the degradation loudly.

---

## Low severity / cleanup

### 7. Dead parameters and a perpetually-running cursor ticker

`StreamingText` accepts but never uses: `selectable`, `showCursor`,
`cursorColor`, `semanticsLabel`, `locale`, `textWidthBasis`,
`textHeightBehavior`. Most are inert, but `showCursor` defaults to `true` and
`_initCursorAnimation` (`streaming_text.dart:559`) starts
`_cursorController.repeat(reverse: true)` — a ticker that runs for the entire
lifetime of every widget while **no cursor is ever drawn** in `build`. That is
wasted CPU/battery on every instance. Either implement the cursor or drop the
field + controller. `_markdownCache` (line 266) is likewise written nowhere and
only `.clear()`ed — dead.

### 8. Accessibility gaps

`semanticsLabel` is accepted but never forwarded to the underlying `Text`
widgets, and the streaming output is not wrapped in a `Semantics` live region, so
assistive tech won't announce incremental updates. For an LLM-chat-oriented
package this is worth addressing (e.g. `Semantics(liveRegion: true, label: …)`).

### 9. Doc/reality drift on exports

`CLAUDE.md` states *"The `StreamingText` widget is imported but not re-exported
(internal)."* In fact `lib/src/streaming/streaming.dart:3` does
`export 'streaming_text.dart';`, and the barrel re-exports `streaming.dart`, so
`StreamingText` **is** public. Decide whether it's public (update the doc) or
internal (remove the export) — this affects the API surface guarantees.

### 10. Whole-widget tap interception

Even setting the data-loss issue (#1) aside, the default `GestureDetector`
covers the entire widget and consumes taps to "complete." Taps on markdown links
during animation are intercepted rather than reaching `onLinkTap`. Consider
limiting the tap target or excluding interactive regions.

### 11. Text-keyed caches grow unbounded

`_rtlGroupCache` and `_completeMarkdownCache` are keyed by the full text string
and only cleared on `dispose`/restart. For a long-lived widget whose text varies
over time, these maps accumulate one entry per distinct string. Bounding them
(LRU, or clear when the active text changes) would cap memory.

### 12. CI coverage

- There is **no PR/push workflow** that runs `flutter analyze` + `flutter test`;
  those only run inside `publish.yml`, i.e. on tag push at release time.
  Regressions aren't caught until publish. Add a lightweight CI workflow on
  `pull_request`/`push`.
- `publish.yml` uses `actions/checkout@v3` (the pages workflow uses `@v4`); minor
  consistency/update.

---

## Things that look good

- Timer/animation-controller lifecycle is carefully handled
  (`_cancelAllTrackedTimers`, `_safeSetState`, disposal guards) — the v1.3.3
  leak-prevention work is solid.
- `LaTeXProcessor` segment parsing (block-over-inline precedence, overlap
  rejection) is clean and well-tested.
- Theme integration via `ThemeExtension` with a proper `lerp`/`copyWith` and a
  documented resolution order.
- `StreamingTextConfig` has correct `==`/`hashCode`/`copyWith`.
- Shimmer is dependency-free and disposes its controller correctly.
- Deprecation of `markdownStyle` → `markdownStyleSheet` is handled with a clear
  removal target (v2.0.0).

## Suggested priority

1. Fix #1 (tap wipes stream) and #3 (stream swap) — correctness/data loss.
2. Reconcile #2 — either animate stream chunks or fix the docs/example.
3. Fix #4 — pubspec SDK constraints (blocks/ misleads real consumers).
4. Address #5/#6 as feature-quality follow-ups.
5. Sweep #7–#12 as cleanup.
