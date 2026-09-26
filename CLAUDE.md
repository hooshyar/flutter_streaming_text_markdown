# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Flutter package (`flutter_streaming_text_markdown`) for animated text display with markdown and LaTeX support. Designed for LLM chat interfaces — provides typing animations (character-by-character or word-by-word), fade-in effects, RTL/Arabic support, and real-time text streaming. Published on pub.dev.

## Development Commands

```bash
flutter pub get              # Install dependencies
flutter analyze              # Static analysis
flutter test                 # Run all tests
flutter test test/engine     # Run one feature folder (engine/widget/stream/
                              # controller/markdown/a11y/render/perf/api)
dart format lib/ test/       # Format code
flutter test --coverage && dart run tool/check_coverage.dart 85  # Coverage gate
dart pub publish --dry-run   # Validate before publishing
```

Tests are organized under `test/` by feature folder (`engine/`, `widget/`,
`stream/`, `controller/`, `markdown/`, `a11y/`, `render/`, `perf/`, `api/`),
mirroring the `lib/src/` layout below. `dart_test.yaml` sets a 60s per-test
timeout and tags the frame-budget benchmark (`test/perf/stream_benchmark_test.dart`)
so it's skipped by default (`flutter test --tags benchmark --run-skipped`
to run it explicitly).

**`flutter test --coverage` note:** in some sandboxed/headless environments,
DDS (Dart Development Service) can hang indefinitely trying to bind a
loopback port during coverage collection, with no effect on a plain
`flutter test` run. If a coverage run stalls, add `--no-dds`.

Example app (do NOT run unless explicitly asked):
```bash
cd example && flutter pub get && flutter run
```

## Architecture

### Widget Hierarchy

`StreamingTextMarkdown` (public API, in `lib/flutter_streaming_text_markdown.dart`)
  → wraps `StreamingText` (internal, `lib/src/streaming/streaming_text.dart`)
    → drives a pure-Dart `RevealEngine` + `RevealScheduler` (`lib/src/engine/`)
    → renders through `StreamingMarkdownView` (`lib/src/render/markdown_renderer.dart`)

`StreamingTextMarkdown` handles scrolling, theme resolution, and shimmer
loading state, then forwards everything else to `StreamingText`, which owns
the reveal state machine, RTL detection, the caret/fade tickers, and
markdown/LaTeX rendering via `gpt_markdown` (NOT `flutter_markdown`).

### `lib/src/engine/` — pure-Dart reveal state, no Flutter imports

The actual "what's been revealed so far" logic is Flutter-free and unit
tested without a widget tester (`test/engine/`):

- **`RevealEngine`** owns `source` (append-only or wholesale-replaced),
  a `cursor` (a UTF-16 offset always on a grapheme boundary, moved via
  `package:characters`' `CharacterRange`), and `revealed` (`source.substring(0,
  cursor)`). `append`/`setSource`/`close`/`step`/`revealAll`/`reset` are the
  whole API. `setSource` keeps the cursor when the new source starts with
  what's already revealed (an append), and otherwise moves it to the
  grapheme floor of the common prefix (a real edit) — this is what makes
  `revealed` an invariant prefix of `source` across both cases. A single
  latch fires completion exactly once, when `cursor == length &&
  inputClosed`; only `reset()` or a non-prefix `setSource` re-arms it.
- **`UnitPolicy`** (`unit_policy.dart`): `CharPolicy` advances N graphemes;
  `WordPolicy` advances one unit = leading whitespace + a maximal
  non-whitespace run + trailing whitespace (Unicode whitespace only, so
  ZWNJ stays inside a word — this is what keeps Arabic/Farsi word-by-word
  correct).
- **`AtomicSpanDetector`** (`atomic_spans.dart`): finds LaTeX `$…$`,
  `$$…$$`, `\(…\)`, `\[…\]` (skipping fenced/inline code), so the cursor
  never lands strictly inside a span while LaTeX is enabled.
- **`RevealScheduler`** (`reveal_scheduler.dart`): exactly one
  `Timer.periodic` per instance; `start`/`pause`/`resume`/`stop`, an
  `interval` setter that applies in place, and idles when there's no
  backlog and input is open. Each tick asks a `RevealPacer`
  (`reveal_pacer.dart`) how many units to reveal — only `FixedPacer` (1 unit
  per tick) ships; the pacer interface is a seam for a future backlog-aware
  pacer.

### `lib/src/render/` — rendering is a pure function of engine state

- **`StreamingMarkdownView`** (`markdown_renderer.dart`) is the *only* place
  a `GptMarkdown` widget is constructed. It merges the legacy top-level
  builders (`imageBuilder`, `linkBuilder`, `sourceTagBuilder`, etc. — used
  when non-null) with `MarkdownRenderOptions` (used otherwise), adapts
  `sourceTagBuilder`/`linkBuilder` onto `gpt_markdown`'s `inline*` builder
  signatures, and installs a default LaTeX builder (via `flutter_math_fork`)
  when `latexStyle`/`latexScale` are set with no user `latexBuilder`.
- **`MarkdownRenderOptions`** (`markdown_options.dart`) bundles every
  `gpt_markdown` 1.3 pass-through that doesn't have its own top-level
  widget parameter (style sheet, block/inline builders, autolink config,
  `useDollarSignsForLatex`, ...) — new `gpt_markdown` forwards land here,
  not as new constructor parameters.
- **`withholdOpenFence`** (`render_text_transform.dart`) is the identity
  once a document is complete, and otherwise withholds an unclosed code
  fence's content from the renderer so gpt_markdown doesn't briefly render
  raw backticks mid-stream. It's a single, replaceable render-only
  transform — never mutates the engine's `source`.
- **`buildFadeSpan`** (`fade_span.dart`) renders a settled-prefix `TextSpan`
  plus one alpha-only `TextSpan` per still-fading `FadeRun` (opacity only —
  the old 10px translate is gone). One `Ticker` drives it, gated by
  `hasActiveFade`, so a plain 5k-char fade uses at most 2 transient tickers.
  The fade is suppressed for Arabic and is now allowed for streams.
- **`StreamingCaret`** / **`caretPulseOpacity`** (`streaming_caret.dart`)
  render an 8x8 pulsing dot; reduced motion holds it at full opacity.
  **`caret_inline.dart`** appends a private-use-area sentinel
  (`caretSentinel`, U+E000 — never real markdown) to the *render* text only
  (never the engine's `source`) and matches it with a `gpt_markdown`
  `InlinePattern` so the caret can sit inside markdown output without
  disturbing the "final text == source" invariant.
- **`StreamingTokens`** (`lib/src/theme/streaming_tokens.dart`) holds the
  handful of hardcoded design-system colors (text/danger) so `lib/` has no
  bare `Colors.blue`/`Colors.red`.

### `lib/src/controller/streaming_text_controller.dart`

`StreamingTextController extends ChangeNotifier`. States: `idle` →
`animating` → `paused` / `completed` / `error`. `markCompleted()`,
`updateProgress(1.0)`, and `skipToEnd()` all route through a single
`_completeOnce()` latch, so `onCompleted` fires at most once per
revealing→complete cycle regardless of which of those three triggered it;
`restart()`/`stop()` re-arm it. `markError(Object, [StackTrace?])` sets the
`error` state and exposes the error via a getter. `speedMultiplier` divides
`typingSpeed` (2.0 = twice as fast). `updateState`/`updateProgress`/
`markCompleted` are internal-use — driven by `StreamingText`, not meant to
be called directly by consumers wiring up their own UI.

### Streaming Input (`Stream<String>`)

Both `StreamingTextMarkdown` and `StreamingText` accept a `stream`
parameter (`Stream<String>?`). When non-null it takes over from `text`
(optional, defaults to `''`); each emitted chunk is appended to the
`RevealEngine`'s source and animated. When not animating (`animationsEnabled:
false` or `typingSpeed == Duration.zero`), chunks reveal immediately as they
arrive and the widget completes once, on stream close, after the reveal has
drained. Swapping the `stream` instance re-subscribes (same semantics as
`StreamBuilder`); a config change (`typingSpeed`/`chunkSize`/`wordByWord`)
mid-stream applies in place and never re-listens. Per-character
`fadeInEnabled` used to be auto-suppressed for streams; the fade is now
opacity-only and streams are no longer a special case — use
`trailingFadeEnabled` for the bottom-edge gradient regardless. README has
copy-pasteable OpenAI / Anthropic SSE → `Stream<String>` bridges.

### Named Constructors as Presets

The main widget has named constructors for common LLM patterns: `.chatGPT()`, `.claude()`, `.typewriter()`, `.instant()`, `.fromPreset()`. These set animation defaults (typing speed, word-by-word, fade-in, chunk size). The `LLMAnimationPresets` class in `lib/src/presets/animation_presets.dart` provides the same configs as `StreamingTextConfig` objects.

### Theme System

`StreamingTextTheme` extends `ThemeExtension<StreamingTextTheme>` — it plugs into Flutter's standard theme system. Resolution order:
1. Widget-level `theme` parameter
2. `Theme.of(context).extension<StreamingTextTheme>()`
3. `StreamingTextTheme.defaults(context)` — derives from Material theme

The `context.streamingTextTheme` extension provides convenient access. A
style or brightness change after completion now takes effect immediately —
`StreamingText` no longer caches resolved styles across builds.

Note: `markdownStyle`, `blockLatexStyle`, `latexScale`, and
`latexFadeInEnabled` on `StreamingTextTheme` are all deprecated (the LaTeX
ones are no-ops now that LaTeX is delegated to `gpt_markdown` — use a
widget-level `latexBuilder` instead); `markdownStyle` → `markdownStyleSheet`.
All are slated for removal in v2.0.0.

### LaTeX Support

LaTeX is delegated entirely to `gpt_markdown` 1.3 (`useDollarSignsForLatex`)
plus `flutter_math_fork` for the default renderer built by
`StreamingMarkdownView` — there is no bespoke LaTeX parser in this package
anymore (the old `LaTeXProcessor`/`TextSegment` regex pipeline was deleted;
neither was ever exported, so this was non-breaking). `latexEnabled: true`
keeps headings/lists/links rendering as markdown alongside the math, and
`$VARS`-style text inside fenced/inline code reaches `codeBuilder` verbatim
instead of being misidentified as LaTeX. LaTeX spans are atomic units during
streaming (see `AtomicSpanDetector` above) and are suppressed from fade-in
by default for performance.

### Tap-to-Complete

`StreamingText` wraps its output in a `GestureDetector`. Tapping while
incomplete calls `RevealEngine.revealAll()` (for an open stream, this only
completes once the stream itself has closed — tapping never fabricates
content that hasn't arrived); tapping once complete is a no-op.
`completeAnimationOnTap` (`bool?`, default resolves to `true`) gates this:
when `false`, tap-to-complete is disabled entirely and the animation plays
through regardless of taps.

### Custom Markdown Components

`components` and `inlineComponents` (`List<MarkdownComponent>?`) are
forwarded as-is to `gpt_markdown`'s `GptMarkdown.components` /
`.inlineComponents` when non-null — but doing so drops `gpt_markdown`'s
incremental segment cache, so **both are deprecated** in favor of
`markdownOptions.blockComponents` / `markdownOptions.inlinePatterns` (via
`MarkdownRenderOptions`), which don't have that cost. `MarkdownComponent`
and the other `gpt_markdown` builder/style types used in
`MarkdownRenderOptions`'s signatures are re-exported from the barrel file,
so consumers don't need a direct `gpt_markdown` dependency just to
construct one.

### RTL / Arabic Text

Arabic detection uses a cached, incrementally-updated Unicode-range regex
in `StreamingText` (recomputed only when the source grows, since input is
append-only or wholesale-replaced). Key behaviors:
- The per-run fade stays suppressed for Arabic text (shaping risk).
- Word-by-word mode's Unicode-whitespace-only boundary rule (see
  `WordPolicy` above) keeps Arabic/Farsi words intact, including ZWNJ.
- The caller's `textDirection` is honored when set; otherwise the detected
  direction is used automatically — `textAlign` is `widget.textAlign ??
  TextAlign.start` (no forced right-alignment).

### Accessibility

`showCursor` (`bool?`; `null` resolves to `stream != null`) shows an 8px
pulsing dot caret while revealing (see `lib/src/render/` above), hidden on
completion so the final rendered text always equals the source exactly.
Reduced motion (`MediaQuery.maybeDisableAnimationsOf`) reveals instantly
with a static caret and no fade. Semantics exclude the partial text mid-
stream and send exactly one announcement (of the full source, or of
`semanticsLabel` when set) on completion. `selectable: true` wraps the
output in a `SelectionArea` (tap-to-complete keeps working). See
`test/a11y/`.

### Shimmer Loading

`StreamingShimmer` widget (`lib/src/widgets/streaming_shimmer.dart`) shows skeleton placeholder while `isLoading: true`. Used for TTFT (Time To First Token) in LLM contexts. Exported directly from the barrel file.

### Deprecated: `StreamProvider` / `DefaultStreamProvider`

`lib/src/streaming/stream_provider.dart` and `default_stream_provider.dart`
are `@Deprecated` — neither is wired to any widget. Pass a `Stream<String>`
straight to `StreamingTextMarkdown.stream` instead. `DefaultStreamProvider`'s
retry path is also documented-but-not-fixed as broken (it re-emits the
*entire* input from the top on retry, rather than resuming from the failed
chunk) since the whole provider is going away in 2.0.0. Still covered by
`test/controller/deprecated_stream_provider_test.dart` since it's public and
shipped.

### Exports

`lib/flutter_streaming_text_markdown.dart` is the barrel file. It exports:
`streaming.dart` (`StreamProvider`, `DefaultStreamProvider`, `StreamingText`),
`streaming_text_theme.dart`, `streaming_text_controller.dart`,
`animation_presets.dart`, `render/markdown_options.dart`
(`MarkdownRenderOptions`), and `StreamingShimmer` from
`widgets/streaming_shimmer.dart` — plus a curated re-export of the
`gpt_markdown` types (`MarkdownComponent`, `GptMarkdownStyleSheet`, the
various `*Builder` typedefs, `InlinePattern`, `InlineDirective`, ...) that
appear in `MarkdownRenderOptions`'s public signatures, so consumers don't
need a direct `gpt_markdown` dependency for that alone.
