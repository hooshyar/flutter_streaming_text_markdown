# Migration guide

This covers the "Correct & fast" rewrite (see `CHANGELOG.md`'s `## Unreleased`
section). **No public API was removed** and the
package version does not change in this release — every item below is either
a deprecation (old code keeps compiling and working, with a warning) or a
behavior fix. You do not have to change anything to upgrade; this guide is
for adopting the new, non-deprecated surface and for the handful of visible
behavior changes worth knowing about.

## SDK / dependency floor

Raise your environment if you're below the new floor:

```yaml
environment:
  sdk: '>=3.7.0 <4.0.0'
  flutter: '>=3.32.0'
```

`gpt_markdown` moves to `^1.3.0` (a transitive dependency; you don't need to
depend on it directly unless you use `MarkdownRenderOptions`'s advanced
fields or the re-exported types).

## Behavior changes to be aware of

These aren't bugs and don't require code changes, but they're visible:

1. **The caret is now on by default while revealing.** If you don't want
   it, pass `showCursor: false`.
   ```dart
   StreamingTextMarkdown(text: text, showCursor: false)
   ```
2. **The per-character fade is opacity-only** (the old 10px translate is
   gone) and **now applies to streams too**, not just static text. If your
   UI depended on the old translate-plus-fade look, or you were relying on
   streams silently having no per-character fade, revisit `fadeInEnabled`
   vs. `trailingFadeEnabled` for your case (see the README's "Choosing a
   fade for streaming content" table).
3. **Config changes apply in place instead of restarting the reveal.**
   Changing `typingSpeed`/`chunkSize`/`wordByWord` while text is revealing
   no longer jumps back to the start.
4. **`onComplete`/`controller.onCompleted` fire exactly once** per
   revealing→complete transition. If you had a workaround for the old
   double-fire (W25) or the old tap-after-completion re-fire (W3), it's no
   longer necessary and can be removed.
5. **An open stream's last grapheme is held back** until the next chunk
   arrives or the stream closes, so a surrogate pair or grapheme cluster is
   never split mid-stream. You may see the very last character of a chunk
   appear one tick later than before.
6. **The reveal default is now `RevealMode.smoothFade`** and
   `Stream<String>` input now paces itself with a catch-up pacer instead of
   a fixed per-tick rate — see the "2.0 reveal defaults" section below.

## 2.0 reveal defaults: `RevealMode` and `StreamPacing`

This is the biggest *default* behavior change in this release, so it gets
its own section.

**What changed.** `StreamingText`, the default `StreamingTextMarkdown`
constructor, `.chatGPT()` and `.claude()` now default to
`revealMode: RevealMode.smoothFade` (DESIGN.md section 4): the engine
reveals in **word units** instead of characters/`chunkSize`, and each newly
revealed word fades in — opacity only, 180ms, `Cubic(0.2, 0, 0, 1)` — for
plain text, `Stream<String>` input, and Arabic content (previously
suppressed there). `.typewriter()` and `.instant()` default to their own
matching `RevealMode` and are unaffected in practice. Separately,
`Stream<String>` input now defaults to catch-up pacing (`StreamPacing`):
instead of revealing one fixed unit every `typingSpeed`, it reveals a
backlog-proportional share every ~50ms (floored at 30 chars/s, fully
drained within 400ms of the stream closing) — a bursty token stream catches
up to the model's actual speed instead of lagging behind at a fixed rate.
Static `text` input is unaffected (still paced by `typingSpeed`).

**Markdown specifically:** `smoothFade` still reveals markdown word-by-word,
but does **not** currently layer a fade animation on top of it (a
`gpt_markdown`-delegated fade was measured, in the real integration, to
regress frame time and rebuild counts well past this package's own perf
budget — see `doc/BENCHMARKS.md`'s "B1-S5 correction"). Plain text keeps
its own fade unaffected by this.

**If your app depends on the exact pre-2.0 timing/cadence** — a specific
`chunkSize`, character-vs-word cadence, or a fixed `typingSpeed`-paced
stream — opt back into it explicitly:

```dart
// Old 1.x behaviour, unchanged: character/chunk reveal, whatever
// wordByWord/fadeInEnabled/fadeInDuration/fadeInCurve/chunkSize/typingSpeed
// you already pass keep meaning exactly what they meant before.
StreamingTextMarkdown(
  text: text,
  revealMode: null,
)
```

`revealMode: null` is available on `StreamingText` and every
`StreamingTextMarkdown` constructor (including `.chatGPT()`/`.claude()`,
which otherwise default to `smoothFade` too). It fully restores the legacy
code path — nothing about it is upgraded silently.

If you only want the old fixed-rate stream pacing but otherwise want to
keep `smoothFade`'s word-unit reveal and fade, override just the pacer:

```dart
StreamingTextMarkdown(
  stream: yourStream,
  pacing: StreamPacing.fixed(const Duration(milliseconds: 50)),
)
```

## Adopting the non-deprecated API

None of this is required — deprecated members still work — but new code
should prefer the replacements:

### `components` / `inlineComponents` → `markdownOptions`

```dart
// Before (still works, but drops gpt_markdown's incremental segment cache)
StreamingTextMarkdown(
  text: text,
  inlineComponents: myInlineComponents,
)

// After
StreamingTextMarkdown(
  text: text,
  markdownOptions: MarkdownRenderOptions(
    inlinePatterns: myInlinePatterns,
  ),
)
```

`markdownOptions.blockComponents` / `.inlinePatterns` cover the same ground
as `components` / `inlineComponents` without the cache cost. See the
README's "MarkdownRenderOptions" section for the full field list.

### `latexFadeInEnabled` → nothing (it's a no-op now)

LaTeX rendering is delegated to `gpt_markdown`, which has no per-run fade
hook of its own, so this flag (both the widget parameter and
`StreamingTextTheme.latexFadeInEnabled`) does nothing. Remove it, or supply
a `latexBuilder` if you need to control LaTeX rendering directly.

### `StreamingTextTheme.blockLatexStyle` / `.latexScale` → `latexBuilder` / widget `latexScale`

These theme-level fields are no-ops now. Use the widget-level `latexScale`
parameter, or a `latexBuilder` for full control.

### `StreamingTextTheme.markdownStyle` → `markdownStyleSheet`

Same shape, new name — `markdownStyleSheet` is what's actually forwarded to
the renderer.

### `StreamProvider` / `DefaultStreamProvider` → `stream:`

These were never wired to any widget. If you were using them to drive your
own UI, switch to passing a `Stream<String>` directly:

```dart
// Before
final provider = DefaultStreamProvider();
final stream = provider.startStream(input); // then wire this up yourself

// After
StreamingTextMarkdown(
  stream: yourOwnStream, // e.g. from your LLM client directly
)
```

If you need SSE-to-`Stream<String>` bridging code, the README's "Bridging
OpenAI / Anthropic SSE to `Stream<String>`" section has copy-pasteable
examples.

### `initialText` → remove it

It was never displayed; `text` is the sole rendered/initial-buffer source.
Removing it from your call sites has no effect on behavior.

## New, additive API you may want to adopt

- **`errorBuilder`** — render your own view when a `stream` errors, instead
  of the default "revealed text + red error line".
- **`selectable: true`** — let users select/copy the rendered text.
- **`semanticsLabel`** — a screen-reader label distinct from the revealed
  text.
- **`cursorColor`** — style the caret independently of your theme's
  text-primary token.

## If you're the `flutter_gen_ai_chat_ui` maintainer

The audit that drove this rewrite specifically tracked your workarounds.
The caret, the reduced-motion handling, the per-run fade now supporting
streams, and `onComplete` firing exactly once should let you remove the
custom reveal ticker and caret you built to work around the old behavior —
see the CHANGELOG's `## Unreleased` "Changed — behavior" section for the
precise list of what changed under you.
