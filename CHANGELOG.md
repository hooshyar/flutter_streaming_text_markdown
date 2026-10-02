# Changelog

## 1.11.0

A ground-up correctness and architecture pass. No public API was removed
or renamed, so this is a zero-breaking-change release; see
`doc/MIGRATION.md` for upgrade notes.

Summary of the release (details in the sections below):

* **Added:** pure-Dart `RevealEngine` core with a catch-up pacer and a
  `smoothFade` reveal mode; a built-in syntax-highlighted `CodeBlockView`
  and `CodeBlockTheme` as the default code renderer (both exported from the
  package barrel); additive `StreamingTextController` accessors
  (`isStreaming`, `markdown`, `copyToClipboard`); accessibility support
  (reduced motion, semantics, selectable text).
* **Changed:** migrated to `gpt_markdown` 1.3; redesigned the markdown fade
  as a cheap paint-only per-word fade; performance work (incremental `mend()`
  scan cache, fade repaint gating).
* **Fixed:** pub score static analysis (`dart analyze --fatal-infos` is
  clean on the latest stable Flutter), plus every W-numbered bug from the
  audit.

### Fixed

Every W-numbered bug from the audit is fixed:

* **W1** — word-by-word mode no longer rewrites whitespace; code
  indentation inside a streamed markdown code block is preserved exactly,
  and `codeBuilder` receives indented code verbatim.
* **W2** — appending text in word-by-word mode after completion no longer
  drops spaces between words.
* **W3** — tapping the widget after it's already complete is now a no-op
  (previously it could re-fire `onComplete`); a tap mid-animation reliably
  reaches the completed state.
* **W4** — Arabic character mode no longer mutates the text (no more
  tripled spaces) and the controller now reaches `completed`.
* **W5/W6** — pause/resume during Arabic or LaTeX content never shrinks the
  revealed text or drops characters; the end state always equals the
  source.
* **W7** — auto-detected RTL direction is now honored in markdown mode
  instead of being silently overridden to LTR.
* **W8** — a style or `Brightness` change after completion now updates the
  rendered output immediately (the stale per-text style cache is gone).
* **W9** — a config change (`typingSpeed`/`chunkSize`/`wordByWord`/
  `markdownEnabled`) mid-stream, or a plain rebuild with no change at all,
  applies in place and never throws `StateError: Stream has already been
  listened to` — including when the caller reads `stream:
  controller.stream` directly inside `build()` instead of caching the
  `Stream` in a field. (`StreamController.stream` returns a new,
  `==`-equal-but-not-`identical` wrapper object on every access, so the
  stream-swap check now compares by value, not identity.)
* **W10** — `latexEnabled: true` no longer throws away markdown rendering:
  headings, lists, and links keep rendering correctly alongside LaTeX. See
  W11 for how `$...$`/`$$...$$` math is now handled.
* **W11** — shell-style `$VARS` inside fenced or inline code are no longer
  misdetected as LaTeX and reach `codeBuilder` verbatim. `latexEnabled`
  rewrites `$...$`/`$$...$$` to `gpt_markdown`'s native `\(...\)`/`\[...\]`
  syntax itself, skipping fenced/inline code, instead of forwarding
  `useDollarSignsForLatex` to `gpt_markdown` (whose own rewrite runs before
  it knows what is code). A `$` is only ever treated as LaTeX when it looks
  like real math rather than currency: `$5`, `Cost $10 - $20`, and `$
  alone` are left as plain text, on both a closed source and mid-stream
  (previously an open stream could freeze right before a bare `$5` while
  waiting for a closing delimiter that would never come).
* **W15** — controller `pause`/`resume`/`stop`/`restart` all work correctly
  in stream mode (previously `pause` was ignored for streams, and
  `stop`/`restart` were ignored in every mode).
* **W16** — a stream error now sets the controller's `error` state (via the
  new `markError`) and renders through the new `errorBuilder`, or a themed
  default view, instead of a hard-coded red error message — the text
  revealed so far always stays on screen.
* **W21** — markdown content inside an unbounded-width parent (e.g. a
  `Row`) no longer throws; width is only forced when the incoming
  constraint is actually bounded.
* **W22** — swapping the `controller` instance now correctly unbinds the
  old controller and binds the new one, instead of leaking a listener and
  leaving both controllers dead.
* **W23** — `animationsEnabled: false` no longer fires `onComplete` on
  every text update.
* **W24** — a non-append text change (anything that isn't a pure suffix
  addition) now keeps the common prefix and continues from there, instead
  of restarting the whole reveal from zero.
* **W25** — `controller.onCompleted` fires **exactly once** per
  revealing→complete transition, no matter which of `updateProgress(1.0)`,
  `markCompleted()`, or `skipToEnd()` triggered it (previously it could
  fire twice).
* **W26** — `.instant(stream:)` and `animationsEnabled: false` with a
  stream now display chunks as they arrive and complete exactly once when
  the stream closes, instead of rendering nothing.
* Arabic text no longer forces `TextAlign.right`; a user's `textAlign` is
  honored, including for Arabic content.
* `_effectiveTheme` now reacts to `widget.theme` changes instead of
  ignoring them after the first build.
* No more per-tick `RegExp` compilation for Arabic detection, and no more
  O(n) `StringBuffer.toString()` buffer copies per stream tick.

### Removed

* The hand-rolled LaTeX renderer and `LaTeXProcessor`/`TextSegment` regex
  pipeline are deleted. Neither was ever exported, so this is non-breaking.
  LaTeX rendering now goes through `gpt_markdown` 1.3 (its native
  `\(...\)`/`\[...\]` syntax — see W11 for how `$...$`/`$$...$$` reach it)
  plus `flutter_math_fork` for the default renderer.
* Internal dead code removed: `_cursorController`, `_markdownCache`,
  `_completeMarkdownCache`, `_isAnimationActive`,
  `_resumeWordByWordTypingFromOldText`, `_safeSetState`, the unbounded
  `_rtlGroupCache`, and the five-plus duplicated `Timer.periodic` bodies
  (replaced by one `RevealScheduler` with exactly one `Timer.periodic`).

### Added

* **`MarkdownRenderOptions`** bundles every `gpt_markdown` 1.3 pass-through
  that doesn't have its own top-level parameter (style sheet, block/inline
  builders, autolink config, `useDollarSignsForLatex`, and more) — the
  single place new `gpt_markdown` forwards land going forward.
* **`errorBuilder`** (`Widget Function(BuildContext, Object error)?`) on
  every constructor, called when `stream` emits an error (see W16 above).
* `StreamingTextController` gains additive accessors for chat-style UIs:
  `isStreaming` (`true` while a `stream:` input is still open or a reveal
  is in progress or paused, `false` once completed or idle), `markdown`
  (the bound widget's full accumulated source text, e.g. behind a "copy"
  button), `copyToClipboard()` (copies `markdown` to the system
  clipboard), and the public `updateSource()` method the bound widget
  calls to publish its current source snapshot and open/closed state so
  `markdown` and `isStreaming` stay truthful.
* **Accessibility**: reduced-motion support (reveals instantly with a
  static caret and no fade), single-announcement semantics with mid-stream
  text excluded from the tree, `semanticsLabel`, and `selectable` (wraps
  output in a `SelectionArea`).
* **`showCursor`** (`bool?`, `null` resolves to `stream != null`) and
  `cursorColor` — an 8px pulsing dot caret shown while revealing, hidden on
  completion.
* `StreamingShimmer` and `MarkdownRenderOptions` are now exported from the
  barrel file, along with a curated re-export of the `gpt_markdown` types
  used in `MarkdownRenderOptions`'s public signatures (`MarkdownComponent`,
  `GptMarkdownStyleSheet`, the `*Builder` typedefs, `InlinePattern`,
  `InlineDirective`, ...), so consumers no longer need a direct
  `gpt_markdown` dependency just to use it.
* `doc/BENCHMARKS.md` — published frame-budget numbers for streaming
  markdown vs. bare `GptMarkdown` (see Performance below).
* `doc/MIGRATION.md` and a weekly CI job (`pub upgrade` + test,
  `pub downgrade` + analyze, and `pana --exit-code-threshold 0`).
* `tool/check_coverage.dart` — parses `coverage/lcov.info` and enforces a
  minimum coverage threshold.

* **`RevealMode`** (`{smoothFade, wordFade, typewriter, instant}`, exported)
  and a `revealMode` parameter on `StreamingText` and every
  `StreamingTextMarkdown` constructor. `smoothFade` (word-unit reveal, a
  180ms opacity-only fade on `Cubic(0.2, 0, 0, 1)`) is the new default on
  `StreamingText`, the default `StreamingTextMarkdown` constructor,
  `.chatGPT()` and `.claude()`; `.typewriter()`/`.instant()` default to
  their own matching mode. Pass `revealMode: null` explicitly to opt out
  entirely and keep the pre-2.0 behaviour driven by the legacy
  `wordByWord`/`fadeInEnabled`/`fadeInDuration`/`fadeInCurve`/`chunkSize`/
  `typingSpeed` parameters — see `doc/MIGRATION.md`.
* **`StreamPacing`** (`StreamPacing.catchUp(...)` / `StreamPacing.fixed(...)`)
  and a `pacing` parameter alongside `revealMode`. `Stream<String>` input
  now defaults to catch-up pacing (a bursty-token-smoothing pacer: reveals
  a backlog-proportional share every ~50ms, floors at 30 chars/s, and
  drains fully within 400ms of the stream closing) instead of one fixed
  unit per `typingSpeed` tick; static `text` input keeps the fixed,
  `typingSpeed`-driven pacer. An explicit `pacing:` always overrides the
  default, on either input kind.
* `StreamingRenderScope` — an internal `InheritedWidget` seam (carrying
  `isStreaming`/`isComplete`/the caret builder) wrapped around the markdown
  view, for a future block-level renderer to read instead of having those
  threaded through by hand. Not part of the public API surface yet.

### Deprecated

* `components` / `inlineComponents` on all 6 constructors — use
  `markdownOptions.blockComponents` / `markdownOptions.inlinePatterns`.
  Passing either (even an empty list) drops `gpt_markdown`'s incremental
  segment cache; `markdownOptions` doesn't have that cost.
* `initialText` — never displayed; has no effect.
* `latexFadeInEnabled` (widget-level and `StreamingTextTheme`-level) — a
  no-op now that LaTeX is delegated to `gpt_markdown`, which has no
  per-run fade hook of its own. Use a `latexBuilder` instead.
* `StreamingTextTheme.blockLatexStyle` and `.latexScale` — no-ops at the
  theme level now; use a `latexBuilder` and the widget-level `latexScale`.
* `StreamingTextTheme.markdownStyle` — use `markdownStyleSheet`.
* `StreamProvider` / `DefaultStreamProvider` (and the types around them) —
  never wired to any widget. Pass a `Stream<String>` directly to
  `StreamingTextMarkdown.stream` instead. Will be removed in 2.0.0.

All deprecations point to their replacement and are scheduled for removal
in 2.0.0; nothing is removed in this release.

### Changed — SDK floor

* `sdk: '>=3.7.0 <4.0.0'`, `flutter: '>=3.32.0'` (raised from `>=3.0.0` /
  `>=3.10.0`) — required by the `gpt_markdown ^1.3.0` upgrade.

### Changed — behavior

These are visible behavior changes, listed explicitly since they can
affect existing consumers (notably `flutter_gen_ai_chat_ui`):

* **The caret is on by default while revealing.** `showCursor` defaults to
  `null`, which resolves to `stream != null` — a live stream now shows a
  pulsing caret unless you explicitly pass `showCursor: false`.
* **The per-character fade is opacity-only.** The old 10px translate
  alongside the opacity fade is gone; only opacity animates now.
* **The per-character fade now applies to streams too**, not just static
  text: it is markdown mode (which gets its own paint-only per-word fade
  via `MarkdownFadeMask`, see the `smoothFade` bullet below) and
  Arabic/RTL where it is unavailable/suppressed, not stream vs. static
  text.
* **Config changes apply in place.** Changing `typingSpeed`, `chunkSize`,
  or `wordByWord` no longer restarts the reveal from the beginning — it
  keeps the current position and applies the new setting going forward.
* **`onComplete`/`onCompleted` fire exactly once per revealing→complete
  transition**, from whichever path reaches completion first (see W25
  above). A rebuild with an unchanged source never re-fires them.
* **An open stream's last grapheme is held back** until the next chunk
  arrives or the stream closes — this is what allows `setSource`/`append`
  to never split a surrogate pair or grapheme cluster at the streaming
  edge.
* **The default reveal is now `RevealMode.smoothFade`** on `StreamingText`,
  the default `StreamingTextMarkdown` constructor, `.chatGPT()` and
  `.claude()` (see Added above): word-unit reveal with a 180ms fade,
  applying to plain text AND markdown streams, AND Arabic content (no
  longer suppressed there, unlike the legacy per-character fade). Markdown
  content fades too: `MarkdownFadeMask` applies a cheap paint-only
  per-word fade in `smoothFade`/`wordFade` modes, without rebuilding the
  `GptMarkdown` span tree (disabled under reduced motion or when
  `animationsEnabled` is `false`). Pass `revealMode: null` to keep the
  exact pre-2.0 behaviour.
* **Fenced code blocks now render through the built-in `CodeBlockView`**
  (exported from the package barrel): a syntax-highlighted block themed by
  `CodeBlockTheme`, with a language-label header and a copy affordance that
  stays hidden but space-reserved while the block is still streaming.
  Passing your own `codeBuilder` opts out and keeps your own rendering,
  unchanged.
* **`Stream<String>` input reveals faster by default** (catch-up pacing —
  see Added above) instead of at a fixed `typingSpeed`-per-unit rate. Pass
  `pacing: StreamPacing.fixed(typingSpeed)` to keep the old rate.

### Performance

* A plain fade over 5k characters now uses at most 2 transient tickers
  (previously one `AnimationController` per character — 500+ concurrent
  tickers at 5k chars in the old implementation).
* A 20k-character markdown stream now runs within ~1.0x-1.3x of bare
  `GptMarkdown` 1.3 (budget: 1.8x), down from roughly 2.1x against
  `gpt_markdown` 1.2.1 in the pre-rewrite implementation — see
  `doc/BENCHMARKS.md` for the full methodology and numbers:

  | Run | ours median | bare median | ratio |
  |---|---|---|---|
  | 1 | 3697us | 3698us | 1.000x |
  | 2 | 4438us | 4337us | 1.023x |
  | 3 | 4146us | 4176us | 0.993x |

* No more per-tick `RegExp` compilation and no more O(n) buffer copies per
  stream tick (both from the audit's `_containsArabic`/StringBuffer
  findings).
* A `gpt_markdown` "hybrid" reveal (letting `GptMarkdown` fade-paint the
  head our engine reveals) was prototyped and rejected: it measured ~1.4x
  bare in isolation, but ~2.3x time and ~12.9x element-rebuilds once wired
  into the real default (caret + engine + catch-up pacer together), over
  both budgets. The shipped default instead fades markdown in
  `smoothFade`/`wordFade` via `MarkdownFadeMask`: a paint-only, per-word
  mask over the rendered paragraphs that repaints without rebuilding
  `GptMarkdown`'s span tree, keeping the real default at ~1.2x-1.5x bare
  across both perf suites. See `doc/BENCHMARKS.md`'s "B1-S5 correction".

## 1.10.1

### Fixed

* **LaTeX (`latexEnabled: true`) now renders real typeset math** instead of
  a Unicode-substitution approximation — fractions, superscripts, and
  radicals are laid out properly via `flutter_math_fork` (already pulled in
  transitively through `gpt_markdown`, now a direct dependency), with a
  plain-text fallback on any parse error.
* Copy-to-clipboard on web no longer throws an uncaught exception on every
  click — the underlying `Clipboard.setData` call is now awaited and its
  failures caught instead of left as an unhandled `Future` rejection.
* `StreamingTextController`: resuming a word-by-word animation after
  `pause()` no longer re-types the last word for one frame. Resume now
  reads the typing timer's own tracked position instead of reconstructing
  it from the displayed text's length, which could drift from the actual
  buffer-writing rules (header newlines, conditional spacing).
* A character's fade-in animation is now guaranteed to end at full opacity
  once typing completes, closing a real-device timing race that could
  intermittently leave a glyph (reported for the em-dash under the
  `bouncy` preset) invisible.
* Example app: the Customization Preview toggle switches no longer clip
  their own labels (`wordByWord`, `fadeIn`, etc. were losing their first
  1-3 characters behind the switch thumb).
* Example app: the web demo's version badge is now generated from
  `pubspec.yaml` at build time instead of a hand-typed literal, so it can't
  go stale on a future release again.

## 1.10.0

### Added

* **`.chatGPT()`, `.claude()`, `.typewriter()`, and `.instant()` now accept
  optional `fadeInDuration`, `fadeInCurve`, and `typingSpeed` overrides**
  (closes [#17]) — pass any of the three to tweak just that part of the
  preset's animation while keeping everything else the preset tunes.
  Omitting them keeps the exact preset defaults as before, so this is fully
  backward compatible.
* Long-stream performance/memory-safety regression tests: a 50k+ character
  static text and a 60k+ character `stream:` payload each complete within a
  bounded pump budget, proving the per-character fade-in suppression under
  `stream != null` holds at real LLM-transcript scale.
* CI now builds the example app for web with `--wasm` on every push/PR, so
  WASM compatibility can't silently regress.

[#17]: https://github.com/hooshyar/flutter_streaming_text_markdown/issues/17

### Fixed

* Internally migrated off `gpt_markdown`'s deprecated `highlightBuilder` to
  `inlineCodeBuilder` (the package's own `highlightBuilder` parameter on
  `StreamingTextMarkdown`/`StreamingText` is unchanged and still works). This
  was the sole cause of a lost pana static-analysis point — score is back to
  160/160.

### Changed

* Raised the `gpt_markdown` dependency lower bound from `^1.1.7` to `^1.2.0`
  — the version that introduced `inlineCodeBuilder`, which the fix above
  requires even at the constraint's lower bound.
* Public API dartdoc coverage raised from 80% to 100% (199/199 elements).
  `public_member_api_docs` is now enabled permanently to prevent regressions.

## 1.9.1

### Fixed

**Stream-mode engine rewrite — chunks now animate instead of rendering instantly**

The `stream:` parameter (added in 1.9.0) had several rough edges once real
LLM traffic hit it. This release rewrites the streaming engine and tightens
the surrounding lifecycle:

* **Chunks now animate per `typingSpeed`/`chunkSize`/`wordByWord`** instead of
  being dumped onto the screen the instant they arrive. `wordByWord` now
  correctly holds back a trailing partial word at a chunk boundary until the
  next whitespace or stream close, so words no longer visibly split mid-token.
* **`onComplete`/`controller.markCompleted()` now fire exactly once** — only
  once the stream itself has closed *and* the displayed text has caught up
  to everything received. Previously these could double-fire or fire before
  the last chunk had finished animating in.
* **`controller.progress` now updates correctly during streaming.** It was
  previously stuck at `0` for the entire stream and only jumped to `1.0` on
  completion.
* **Tap-to-complete and `controller.skipToEnd()` are now stream-safe.** In
  stream mode, both now instantly catch the displayed text up to whatever has
  been received so far — they never erase already-streamed content. They only
  trigger full completion if the underlying stream has already closed;
  previously tapping mid-stream wiped all streamed text and could double-fire
  `onComplete`.
* **`didUpdateWidget` now detects a `stream` instance swap** (e.g. a chat UI
  moving on to the next message). Previously swapping in a new `Stream<String>`
  was silently ignored and its content never appeared. The old subscription is
  now properly torn down and the new one subscribed — including the
  `stream → null` and `null → stream` transitions.
* **`autoScroll` (on `StreamingTextMarkdown`) now pins to the bottom as content
  grows during animation/streaming**, not only once at the very end. Backed by
  a new optional `onTextChanged` callback on `StreamingText`.
* Removed a phantom repeating cursor-blink `AnimationController` ticker that
  ran continuously with nothing ever rendering it — a source of needless
  battery drain and a cause of `pumpAndSettle` hangs in tests.

**Code-fence render stability while typing.** While a ``` code fence was
still being typed, its raw backtick markers rendered as literal text; the
instant the closing fence completed, gpt_markdown reformatted the block as
a styled code widget, stripping those markers — the visible text shrank by
a few characters at that exact moment, reading as a stutter/flicker on top
of the typing animation. The markdown *render* now withholds a trailing
unclosed fence until it balances, so code blocks only ever appear in their
final styled form. Typing position, progress, and completion timing are
unchanged — this affects display only.

## 1.9.0

### New Features

**`StreamingTextMarkdown` now accepts a `Stream<String>` directly**

The headline widget finally lives up to its name. You can pass a `stream:` parameter to `StreamingTextMarkdown` (and every preset constructor) instead of dropping down to the lower-level `StreamingText`. Each chunk emitted by the stream is appended to the rendered text and animated using the active typing settings.

```dart
StreamingTextMarkdown(
  stream: openAiChat(prompt),     // Stream<String> from your LLM client
  markdownEnabled: true,
  trailingFadeEnabled: true,      // recommended for streams
  onComplete: () => setState(() => _isStreaming = false),
)
```

* `stream` — `Stream<String>?`. When non-null, takes over from `text` and content arrives via the stream.
* `text` is now optional (defaults to `''`). Existing code passing `text:` keeps working unchanged.
* Per-character `fadeInEnabled` is automatically suppressed when `stream` is set (one `AnimationController` per glyph on an unbounded stream would exhaust memory). Use `trailingFadeEnabled` for a smooth gradient reveal.
* Available on every constructor: default, `.chatGPT()`, `.claude()`, `.typewriter()`, `.instant()`, `.fromPreset()`. Non-breaking.

README has new copy-pasteable bridges for OpenAI Chat Completions and Anthropic Messages SSE → `Stream<String>`.

**Opt out of tap-to-complete** (PR #15, thanks @AdamBurnett-Tonal)

* New `completeAnimationOnTap` flag (`bool`, defaults to `true`). By default, tapping the widget while it animates jumps straight to the finished text — set this to `false` to let the animation play through uninterrupted regardless of taps.
* Available on `StreamingTextMarkdown`, every preset constructor, and the lower-level `StreamingText`. Non-breaking — existing behavior is the default.

## 1.8.0

### New Features

**Custom markdown components** (closes #13)

Expose `gpt_markdown`'s component lists so you can override how block- and inline-level markdown elements are rendered — headers, lists, bold, italic, tables, etc. Both parameters are forwarded as-is to the underlying `GptMarkdown` widget; passing `null` (the default) keeps `gpt_markdown`'s built-in component list.

* `components` — `List<MarkdownComponent>?`, block-level overrides (headers, lists, code blocks, tables, …)
* `inlineComponents` — `List<MarkdownComponent>?`, inline-level overrides (bold, italic, strikethrough, links, …)

Available on every constructor — default, `.chatGPT()`, `.claude()`, `.typewriter()`, `.instant()`, `.fromPreset()`. Non-breaking.

## 1.7.3

### Bug fixes

* **Fix pub.dev static analysis failure causing 90/160 score.** `gpt_markdown` 1.1.7 changed the `ImageBuilder` typedef from 2 args to 4 args (added optional `width`/`height` parsed from image alt text). Our constraint `^1.1.6` permitted 1.1.7, so pana resolved to it and the `imageBuilder` argument at `streaming_text.dart:1708` failed type-checking — which cascaded into platform-support detection also reporting 0/20. Bumped the dependency to `^1.1.7` and added a thin internal adapter so the public `imageBuilder(BuildContext, String)` signature stays unchanged. No user code changes required. Restores full 160/160 pub.dev score.

## 1.7.2

### Bug fixes

* **Trailing fade now actually dismisses on completion** (closes #12). Previously the trailing-edge gradient would stay applied forever after typing/streaming finished — `_triggerTrailingFade()` was called during streaming via `_updateProgress`, but every completion path set `_isComplete = true` without re-triggering the dismiss animation. Centralized completion through a new `_handleCompletion()` helper that fires `onComplete` and triggers the fade-out together. Affected all 11 completion sites (typing finish, stream `onDone`, skip-to-end, tap-to-skip, append-completion, etc.).

### Documentation

* Documented the silent fade-in suppression for streams and Arabic content (#11). `fadeInEnabled` and `stream` now have explicit dartdoc on the interaction; README has a "Choosing a fade for streaming content" table.

### Tests

* Added regression tests covering both completion paths (`text` prop + `Stream<String>`) with `trailingFadeEnabled: true`.

## 1.7.1

* Fix lint info (curly braces) for full 160/160 pub.dev score
* All trailing fade, Arabic word splitting, and setState fixes included

## 1.7.0

### New Features

**Custom markdown builders** (closes #10)

Expose `gpt_markdown`'s builder callbacks so you can customize how images, links, code blocks, and more are rendered inside streaming text.

* `imageBuilder` — custom widget for markdown images
* `onLinkTap` — callback when a link is tapped
* `codeBuilder` — custom widget for code blocks
* `latexBuilder` — custom widget for LaTeX expressions
* `sourceTagBuilder` — custom widget for source tags
* `highlightBuilder` — custom widget for highlighted text
* `linkBuilder` — custom widget for links

All parameters are optional and available on every constructor including `.chatGPT()`, `.claude()`, `.typewriter()`, `.instant()`, and `.fromPreset()`.

```dart
StreamingTextMarkdown.chatGPT(
  text: response,
  markdownEnabled: true,
  imageBuilder: (context, url) => CachedNetworkImage(imageUrl: url),
  onLinkTap: (url, title) => launchUrl(Uri.parse(url)),
  codeBuilder: (context, name, code, closed) => MyCodeBlock(code: code),
);
```

**Trailing fade effect** — new `trailingFadeEnabled` parameter

Optional trailing gradient fade at the bottom edge while text is streaming. The fade holds steady during streaming and smoothly animates away when complete. Opt-in via `trailingFadeEnabled: true` — disabled by default.

### Bug Fixes

* **Fix emoji character skipping during animation resume** (closes PR #9) — `_displayedText.length` returned UTF-16 code units but was used as an index into grapheme cluster lists, causing characters after emoji to be dropped. Now uses `_displayedText.characters.length`.
* **Fix Arabic/RTL word splitting** — the previous regex stripped Arabic punctuation and hamza (ء) as delimiters and didn't preserve markdown syntax (headers, blockquotes, lists). Now uses the same markdown-aware splitting as LTR text.
* **Fix trailing fade blinking** — the trailing gradient was resetting on every animation tick, causing visible flashing. Now holds steady during streaming and animates away once on completion.
* **Fix setState during build in example** — `StreamingTextController` callbacks in the example's ControllerSection could fire during the build phase. Deferred with `addPostFrameCallback`.

## 1.6.0

### ✨ New Features

**Shimmer loading state — `isLoading` parameter**

Show an animated skeleton placeholder while waiting for the first LLM token (TTFT).
No more blank screen between sending a request and the first character appearing.

* **`isLoading: false`** — New parameter on all constructors and named variants. When `true`, displays an animated shimmer skeleton instead of the text widget. Defaults to `false` — all existing code is completely unaffected.
* **`shimmerLineCount: 3`** — Controls how many skeleton lines are shown. Defaults to 3.
* **Pure Flutter implementation** — No external shimmer package. Uses `AnimationController` + `LinearGradient` sweep. Adapts to light/dark theme automatically.
* **Markdown tables confirmed** — gpt_markdown renders tables natively. Added documentation and example.

```dart
// Usage example
StreamingTextMarkdown.chatGPT(
  text: _accumulatedText,
  isLoading: _waitingForFirstToken,  // true until first token, then false
)
```

### 🔧 Improvements

* Upgraded `gpt_markdown` dependency to `^1.1.6` — picks up table column alignment fix, ordered list bug fix, Flutter 3.35 compatibility, and heading style customization fixes

## 1.5.0

### ✨ New Features

**Trailing-edge fade animation for markdown and RTL content**

Previously, `fadeInEnabled: true` only worked with plain text (`markdownEnabled: false`). This release brings smooth streaming animations to all content types.

* **Markdown fade-in** — When `fadeInEnabled: true` and `markdownEnabled: true`, a trailing-edge gradient fade animates at the bottom of the content as new text streams in, using the configured `fadeInCurve` and `fadeInDuration`
* **RTL/Arabic support** — Fade animations now work correctly with Arabic and Hebrew text (previously disabled for RTL languages)
* **Block LaTeX protection** — When streaming inside a `$$...$$` block, uses a gentle opacity pulse instead of gradient mask to avoid visually cutting through equations
* **Revolutionary example page** — Complete showcase redesign with all 17 package features: named constructors, 9 presets, full controller API, markdown, LaTeX, RTL, theme system, live customization playground, and GitHub Pages deployment
* **GitHub Pages live demo** — https://hooshyar.github.io/flutter_streaming_text_markdown/

### 🔧 Improvements

* Example page rebuilt from scratch: 11 files, 1300+ lines, dark/light mode, responsive
* All links in example are now clickable (pub.dev, GitHub, License)
* Preset grid shows all 9 `LLMAnimationPresets` with live mini-previews
* Controller section demonstrates full `StreamingTextController` API with progress bar, state display, speed multiplier
* Added pub.dev badge count in hero section

### ✅ Compatibility

Fully backward compatible — existing code unchanged. Fade-in for markdown only activates when both `fadeInEnabled: true` AND `markdownEnabled: true` are set.

---

## 1.4.0

### ✨ New Features

**This release adds a dedicated `markdownStyleSheet` property (typed as `TextStyle`) while maintaining 100% backward compatibility. Includes all v1.3.3 stability fixes.**

* **Dedicated Markdown Style Property** - Cleaner API for markdown styling (Fixes Issue #5)
  - NEW: `StreamingTextTheme.markdownStyleSheet` property accepts `TextStyle`
  - NEW: `StreamingTextMarkdown.styleSheet` now properly typed as `TextStyle?`
  - Uses `gpt_markdown` package for proper markdown rendering
  - Example:
    ```dart
    StreamingTextTheme(
      markdownStyleSheet: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: Colors.black87,
      ),
    )
    ```

### 🔄 Backward Compatibility

* **Zero Breaking Changes** ✓
  - `StreamingTextTheme.markdownStyle` still works (deprecated with migration path)
  - Old code using `markdownStyle: TextStyle()` continues to work perfectly
  - New code can use `markdownStyleSheet` for a clearer API
  - Migration timeline: v1.4.0 (add markdownStyleSheet) → v2.0.0 (remove markdownStyle)

### 📚 Documentation Alignment

* **Fixed Documentation Mismatch** - Code now matches README examples
  - README examples now accurately show `TextStyle` usage
  - API documentation updated to reflect actual types
  - Closes Issue #5 opened Oct 16, 2025

### 🔧 Migration Guide

**No migration required!** Old code continues to work:

```dart
// Old way (still works, deprecated)
StreamingTextTheme(
  markdownStyle: TextStyle(fontSize: 16),
)

// New way (recommended)
StreamingTextTheme(
  markdownStyleSheet: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: Colors.black87,
  ),
)
```

### 🛡️ Includes All v1.3.3 Stability Fixes

* Fixed setState race conditions (prevents navigation crashes)
* Fixed timer memory leaks (better long-running app performance)
* Fixed AnimationController disposal errors
* Fixed stream double-wrapping issues
* 500x faster RTL/Arabic text processing
* Enhanced error handling and debugging

### 🎯 Upgrade Recommendation

**Recommended upgrade** - Get both new features AND stability improvements:
```yaml
dependencies:
  flutter_streaming_text_markdown: ^1.4.0
```

No code changes required, but you now have access to powerful markdown styling options!

---

## 1.3.3

### 🛡️ Stability & Reliability Improvements

**This release focuses on internal bug fixes and performance optimizations with ZERO breaking changes. Safe to upgrade from v1.3.2 with no code modifications required.**

### 🐛 Critical Bug Fixes

* **Fixed Race Condition Crashes** - Eliminated rare crashes during navigation/disposal
  - Implemented safe setState wrapper to prevent crashes when widget is disposed during animation
  - Added comprehensive mounted checks throughout animation lifecycle
  - Fixes crash reports during fast navigation scenarios
  - All existing code continues to work identically

* **Fixed Timer Memory Leaks** - Resolved memory leaks in long-running applications
  - Implemented internal timer tracking to prevent orphaned timers
  - Automatically cancels all timers on widget disposal
  - Prevents timer accumulation during rapid text updates
  - No API changes - improvement is completely transparent

* **Fixed AnimationController Disposal Errors** - Enhanced controller cleanup safety
  - Added proper animation state checks before disposal
  - Prevents "dispose while animating" errors
  - Improved error handling with specific exception types
  - Maintains exact same external behavior

* **Fixed Stream Double-Wrapping** - Corrected broadcast stream handling
  - Now checks if stream is already broadcast before wrapping
  - Prevents resource leaks with broadcast streams
  - Maintains backward compatibility with all stream types

### ⚡ Performance Optimizations

* **Optimized RTL/Arabic Text Processing** - Up to 500x faster for Arabic text
  - Pre-compiled regex patterns for word boundary detection
  - Eliminated string concatenation in hot paths
  - Reduced CPU usage during Arabic text animation
  - Zero visual changes - same beautiful animations

* **Reduced Memory Allocations** - More efficient resource usage
  - Improved timer management reduces memory footprint
  - Better controller pooling prevents memory spikes
  - Optimized cache cleanup on disposal

### 🔧 Internal Improvements

* **Enhanced Error Handling** - Better debugging experience
  - Specific error catching for disposal vs other errors
  - Errors are now re-thrown for proper debugging
  - Improved stack traces for troubleshooting

* **Code Quality** - Internal refactoring for maintainability
  - Added comprehensive inline documentation
  - Versioned internal changes (v1.3.3 markers)
  - Improved code organization

### ✅ Backward Compatibility

* **Zero Breaking Changes** ✓
  - All public APIs remain identical
  - Default behavior preserved exactly
  - No migration required
  - All existing tests pass
  - Safe drop-in replacement for v1.3.2

### 📊 Testing

* Verified all existing tests pass (63% coverage maintained)
* Added internal stress testing for memory leaks
* Validated performance improvements with benchmarks
* Confirmed zero regressions in behavior

### 🎯 Upgrade Recommendation

**Highly recommended upgrade** - Improves stability and performance with zero risk:
```yaml
dependencies:
  flutter_streaming_text_markdown: ^1.3.3
```

No code changes needed. Your app will immediately benefit from improved stability.

---

## 1.3.2

### ✨ New Features
* **Animation Disable Option** - Added `animationsEnabled` parameter to all constructors allowing complete animation disabling
  - All constructors now support `animationsEnabled: false` for instant text display
  - Useful for performance-critical scenarios or user accessibility preferences
  - Maintains full compatibility with existing code (defaults to `true`)

### 🔧 Code Quality Improvements
* **Enhanced Static Analysis** - Resolved all remaining static analysis warnings for perfect pub.dev scoring
* **Dependency Updates** - Updated flutter_lints to 6.0.0 and other dependencies to latest versions
* **Performance Optimizations** - Removed unused fields and optimized animation state management

### 🧪 Testing
* **Comprehensive Test Coverage** - Maintained 63% test coverage with 69 out of 70 tests passing
* **Animation Continuation Tests** - Enhanced test suite to verify text append functionality works correctly

## 1.3.1

### 🐛 Critical Bug Fixes
* **Fixed Issue #3: Markdown Animation Conflict** - Resolved critical issue where animations would freeze when markdown was enabled
  - Implemented animation-aware caching system that only caches when animation is complete
  - Added progressive markdown rendering during animation to prevent UI blocking
  - All markdown + animation combinations now work correctly
* **Fixed Issue #1: Animation Restart Bug** - Resolved streaming text restarting entire animation instead of continuing from new content
  - Added incremental animation tracking with proper state management
  - Streaming text now continues animation from where it left off instead of restarting
  - Improved performance for real-time streaming scenarios

### 🔧 Code Quality Improvements
* **Static Analysis Cleanup** - Removed unused variables and fields to achieve perfect static analysis score
* **Formatting** - Applied consistent Dart formatting across all source files
* **Performance** - Optimized animation state management for better memory efficiency

### 🧪 Testing Enhancements
* **Comprehensive Test Coverage** - Added extensive test suite covering all reported issues
* **Issue Reproduction Tests** - Added specific tests that reproduce and verify fixes for GitHub issues
* **Streaming Behavior Tests** - Added tests validating proper incremental streaming animation

## 1.3.0

### 🔢 LaTeX Support
* **Mathematical Expressions** - Added comprehensive LaTeX support for inline ($x^2$) and block ($$E=mc^2$$) mathematical expressions
* **Unicode Conversion** - LaTeX expressions are converted to Unicode symbols for proper rendering
* **Atomic Animation** - LaTeX expressions are treated as atomic units during streaming animation
* **Theme Integration** - Extended StreamingTextTheme with latexStyle, latexScale, and latexFadeInEnabled properties
* **Performance Optimization** - LaTeX expressions can disable fade-in animations for better performance

### 🔧 Package Architecture Improvements
* **Dependency Migration** - Migrated from multiple markdown packages to single gpt_markdown package
* **Word-by-Word Markdown** - Fixed markdown rendering issues in word-by-word animation mode
* **Caching System** - Added intelligent caching for LaTeX processing and markdown parsing
* **Performance Enhancements** - Optimized text processing and animation performance

### 🛠️ Developer Experience
* **LaTeX Configuration** - Added latexEnabled, latexStyle, latexScale, and latexFadeInEnabled parameters
* **Enhanced Documentation** - Comprehensive LaTeX usage examples and configuration guide
* **Test Coverage** - Added extensive test suite for LaTeX functionality and integration
* **Example Updates** - Updated example app with LaTeX demonstration and scientific content

### 🐛 Bug Fixes
* **Unused Import Cleanup** - Removed unused gpt_markdown import from streaming_text.dart
* **Animation Consistency** - Fixed word-by-word animation with mixed markdown and LaTeX content
* **Memory Management** - Improved disposal of LaTeX processing resources

## 1.2.1

### 🐛 Bug Fixes & Pub.dev Optimization
* **Removed deprecated textScaleFactor** - Removed deprecated parameter to fix static analysis warnings
* **Fixed pub.dev scoring** - Removed non-existent issue tracker URL to improve pub.dev scoring
* **Code cleanup** - Removed TODO comments and improved code documentation

## 1.2.0

### 🚀 Major Features
* **StreamingTextController** - Added programmatic control for pause/resume/skip/restart functionality
* **LLM Animation Presets** - Added ChatGPT and Claude-style animation presets optimized for AI text streaming
* **Convenient Constructors** - Added `StreamingTextMarkdown.chatGPT()`, `.claude()`, `.typewriter()`, `.instant()` constructors

### 🎯 LLM Integration Enhancements
* Enhanced package description and tags for better discoverability in LLM use cases
* Added comprehensive example app showcasing ChatGPT-style, Claude-style, and controller demos
* Optimized animation speeds and behaviors specifically for AI text streaming scenarios

### 🛠️ Developer Experience
* Added `StreamingTextConfig` class for reusable animation configurations
* Added progress tracking and state management through controller callbacks
* Added animation presets: `chatGPT`, `claude`, `typewriter`, `gentle`, `bouncy`, `chunks`, `rtlOptimized`, `professional`
* Added animation speed enums: `slow`, `medium`, `fast`, `ultraFast`

### 🔧 Technical Improvements
* Updated deprecated API usage (`withOpacity` → `withValues`)
* Fixed package structure (`docs/` → `doc/`, added `.pubignore`)
* Improved Flutter compatibility and dependency management
* Enhanced error handling and controller lifecycle management

### 📱 Example App Overhaul
* Complete redesign with 4 tabs: ChatGPT Style, Claude Style, Controller Demo, Custom Settings
* Real-time streaming simulation with Flutter development content
* Interactive controller demo showing pause/resume/skip/restart functionality
* Performance optimizations and modern UI design

### 🐛 Bug Fixes
* Fixed animation disposal and memory management
* Improved RTL text handling and performance
* Fixed deprecated API warnings and analysis issues

## 1.1.0

* Added professional theme system with StreamingTextTheme
* Added support for custom markdown styling through theme extension
* Added proper theme inheritance and fallback system
* Added documentation for theme customization
* Improved style sheet handling in StreamingText widget
* Made padding configuration more flexible
* Maintained full backward compatibility

## 1.0.2

### Improvements
- 📦 Updated dependencies to latest compatible versions
- 🔧 Improved package structure and organization
- 📚 Enhanced API documentation and examples
- ⚡️ Performance optimizations for text rendering

## 1.0.1

### Improvements
- 🔄 Updated text scaling implementation to use modern textScaler
- 📚 Documentation improvements
- 🐛 Minor bug fixes and performance optimizations

## 1.0.0

Initial stable release 🎉

### Features
- ✨ Markdown rendering with support for headers, bold, italic, and lists
- ⌨️ Character-by-character and word-by-word typing animations
- 🎭 Customizable fade-in animations
- 🌐 RTL (Right-to-Left) language support
- 📱 Responsive and customizable design
- 🎯 Interactive tap-to-complete feature
- 🔄 Real-time text streaming support
- 🎨 Customizable styling options

### Improvements
- 📚 Comprehensive documentation
- ✅ Full test coverage
- 🔧 Modern text scaling implementation
- 🧹 Code cleanup and optimization
