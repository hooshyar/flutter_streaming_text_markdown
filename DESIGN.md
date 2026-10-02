# DESIGN.md: flutter_streaming_text_markdown

The committed design direction for the package's zero-config rendering, its streaming reveal, and its showcase site.
Read this before touching any visual or motion default. If a change contradicts this file, change this file first, in the same PR.

Sibling: `flutter_gen_ai_chat_ui` DESIGN.md (branch `agent/codeblock-_integration`). This package is the animation and markdown engine underneath that chat UI, so the two share one token set, one type scale, one motion spec and one code-block look. Where this file says "shared", the sibling file is the source of truth and both must change together.

---

## 1. Thesis

**Text arrives, it never jumps.** Every token lands where it will stay, fades in once at the arrival edge, and nothing above it moves.

Design read: rendering engine for LLM answers, judged in 5 seconds on pub.dev by a Flutter developer, then read for minutes by their end users. Language: calm, typographic, document-like (claude.ai / ChatGPT / Streamdown restraint). Dials: `DESIGN_VARIANCE 3 / MOTION_INTENSITY 4 / VISUAL_DENSITY 4` for the package defaults; `6 / 6 / 3` for the showcase site.

Four rules everything else follows:

1. **Arrival is the only motion.** New text fades in over one short duration. No bounce, no slide, no blur, no per-character typewriter by default. Typewriter stays available as an opt-in preset, never the default.
2. **Half-written markdown never shows its syntax.** A reader must never see `**`, a lone backtick, `| --- |`, `$$` or a dangling `[text](` mid-stream. The engine mends or holds back incomplete syntax (section 5).
3. **The reveal follows the model, not a metronome.** Reveal speed adapts to the backlog, so the text never falls seconds behind a fast model and never stutters on a bursty one (section 4.3).
4. **Layout is monotonic.** Content only grows downward. Blocks above the arrival edge are frozen (memoized); no block changes height or re-wraps after it is complete, no code block pops in whole, no table reflows its columns.

---

## 2. References and what we borrow

| Reference | Borrow exactly this | Do not borrow |
|---|---|---|
| **Vercel Streamdown** | Unterminated-markdown repair before parsing (its `remend` / parse-incomplete-markdown step); splitting the source into top-level blocks and memoizing every block except the last; code blocks that stream line by line inside their final frame with a copy button; hardened links and images (allowed prefixes); KaTeX-quality math; GFM tables. | Its web-only dependencies (Shiki, Mermaid via JS). We mirror the behaviour in Dart. |
| **ChatGPT** | Fade-in of newly arrived text (shipped around March 2025); reading column around 48rem. Its exact timings are not public. The OpenAI forum backlash (readability, "feels slower") is why our fade is short (180ms), ends at full opacity, never dims settled text, and can be switched off. | Long fades or any semi-transparent text that lingers. |
| **claude.ai** | Bubble-less document prose; generous paragraph rhythm; a reveal that feels paced even on a bursty network. No public spec; this is an observed quality target, not a measured one. | The cream palette and proprietary fonts. |
| **Gemini** | Buffering large API chunks into a paced reveal rather than dumping them. | Gradient shimmer on the whole message. |
| **Streamdown animation** | Per-word fade at 150ms, with the backlog capped at 320ms so the reveal never trails far behind. | Its lack of reduced-motion handling (Streamdown has none; we do, section 7). |
| **gpt_markdown 1.3.x** (our dependency) | Its settled-segment cache, `SliverGptMarkdown`, and adaptive reveal speed (`backlog / 0.4s`). Build on these rather than re-implementing; the engine must never pass `components:` unless the caller did, because that forces gpt_markdown's legacy slow parser. | Its `blurIn` / `wave` reveal styles. |
| **llm-ui / flowtoken** | A throttle that smooths bursty token delivery into an even visual rate with catch-up, and per-chunk fade as the only animation. | Blur-in and drop-in effects, and flowtoken's 1s default fade (far too slow). |
| **Sibling chat UI** | Tokens, type scale, motion tokens, `CodeBlockTheme` palettes, JetBrains Mono, caret spec. | Chat-shell concerns (bubbles, composer). This package renders content only. |

---

## 3. Tokens (shared)

This package does not paint canvases or bubbles. It paints text, code blocks, tables, rules, quotes and math. It uses the shared neutral ramp for those, and it resolves tokens from brightness (`Theme.of(context).brightness`), never from `colorScheme.surface*` (M3 seed tinting gives the lavender cast visible in `before/40-harness-*`).

| Token | Light | Dark | Used for |
|---|---|---|---|
| `textPrimary` | `#18181B` | `#EDEDEF` | Body, headings, math, caret |
| `textSecondary` | `#52525B` | `#A8A8B0` | Blockquote text, list bullets |
| `textTertiary` | `#6B6B73` | `#8C8C94` | Code language label, held-back math source, table captions |
| `border` | `#E4E4E2` | `#2A2A2F` | Table hairlines, `hr`, code border, blockquote rule (light) |
| `borderStrong` | `#85858D` | `#6A6A72` | Blockquote rule (dark) |
| `surfaceSunken` | `#F3F3F1` | `#1C1C1F` | Table header row |
| `inlineCodeBg` | `#EEEEEB` | `#232327` | Inline `code` |
| `codeBg` | `#F6F6F4` | `#161618` | Fenced code, block math frame |
| `codeBorder` | `#E4E4E2` | `#2A2A2F` | Fenced code, block math frame |
| `accent` | host `colorScheme.primary` | host `colorScheme.primary` | Links, selection only |

Syntax colours: the sibling's `CodeBlockTheme.light()` / `.dark()` palettes, unchanged (GitHub-derived with the comment `#656D76` and annotation `#8A5C00` AA fixes in light).

Rules:
- No `Colors.*` literal in any default path. Today `Colors.blue` is the LaTeX fallback colour and `Colors.red` the error colour; both become tokens (`textPrimary`, and a `danger` token `#C4321C` / `#FF7A66`).
- Resolution order stays: widget param > `StreamingTextTheme` extension > tokens derived from brightness. `StreamingTextTheme` gains a `tokens` field so the chat UI can pass its `ChatTokens` straight through.
- Styles are resolved in `build`, never cached across a theme change (see gap G2: cached completed widgets keep dark-mode text after switching to light).

---

## 4. Streaming reveal spec

### 4.1 Recommended default mode: `RevealMode.smoothFade`

The default constructor and `.chatGPT()` / `.claude()` all resolve to this unless the caller opts out.

- **Unit:** word (whitespace-delimited run, grapheme-safe). CJK and other scripts without spaces fall back to grapheme clusters in runs of 2.
- **Arrival animation:** opacity 0 to 1, no translate, no scale, no blur.
- **Duration:** `streamFade` = **180ms** (shared token).
- **Curve:** enter curve `Cubic(0.2, 0, 0, 1)` (shared emphasized decelerate).
- **Implementation contract:** one `Ticker` per widget, not one `AnimationController` per glyph. The reveal state is a list of `(startOffset, revealedAt)` runs; each frame, runs younger than 180ms get `color.withValues(alpha: curve(t))` on their `TextSpan`; older runs merge into the settled prefix. At most about 4 runs fade at once (180ms / 50ms tick), so cost is constant per frame regardless of answer length. This lifts today's restrictions: fade works on `Stream<String>` input, on Arabic/RTL, and inside markdown.
- **Settled prefix is static.** Completed top-level blocks (section 6.1) render from a memoized widget and never rebuild during the stream.

Other modes stay available as named presets, restyled to the same tokens: `RevealMode.typewriter` (character drip, no fade, for effect), `RevealMode.instant` (no reveal), `RevealMode.wordFade` (today's `.claude()`: word units, 220ms fade). `bouncy`, `gentle`, `dramatic` and friends become deprecated aliases that map to one of these four; motion vocabulary beyond fade is out.

### 4.2 Caret (shared spec)

- An **8x8 circle** in `textPrimary`, placed inline after the last revealed glyph (as a `WidgetSpan`, baseline-aligned, 4px leading gap), not on a new line.
- Inside an open code block, the caret sits at the end of the last code line and uses the code base colour.
- Pulses opacity 0.35 to 1.0 over `caretPulse` = **900ms**, sine in-out, repeating, only while the stream is open.
- Shown when `showCursor` is true (default **true** for stream input, false for static `text`). Today `showCursor` exists but renders nothing; that is a bug, not a design choice.
- On stream end the caret fades out over `fast` = 150ms.
- Before the first token: the caret alone at the start position (a "ready" dot), no shimmer. The shimmer skeleton remains opt-in via `isLoading`.

### 4.3 Pacing: smoothing bursty tokens

LLM output arrives in bursts (network frames of 20 to 400 chars, then silence). The reveal must neither dump a burst at once nor lag behind.

- Tick on the frame clock (vsync), budgeting in 50ms windows (shared with the sibling reveal ticker).
- Per 50ms window, reveal `max(1 word, ceil(backlog * 0.16))` characters, snapped forward to the next word boundary, where `backlog = received - revealed`. This is the sibling's catch-up factor. It gives an exponential catch-up with a time constant of about 300ms: a 400-char burst is fully on screen in about 0.9s, and steady 60 tok/s streams render at model speed.
- Floor: never slower than 30 chars/s while backlog exists. Ceiling: none (a stalled UI is worse than a fast one).
- When the stream closes, drain the remaining backlog within at most **400ms** regardless of size.
- `typingSpeed` keeps its meaning only for static `text` input and for `RevealMode.typewriter`. For `Stream<String>` input the pacer above is used unless the caller explicitly passes `pacing: Pacing.fixed(typingSpeed)`.
- Why: today the stream drain moves one unit per `typingSpeed` (default 50ms, so 20 chars/s). A 1,100-char answer that the model finishes in about 8s is still at paragraph one at 8s in the default constructor (`before/41-harness-default-at-model-done-8s.png`).

### 4.4 Tap-to-complete and controller

Unchanged API. Tap-to-complete drains the backlog with no fade (instant settle) and hides the caret if the stream is done. Controller progress for streams is `revealed / received`, labelled as such in docs.

---

## 5. Incomplete-syntax rendering rules ("mend")

Before each parse of the **live (last) block only**, run a pure `mend(String tail) -> String` pass, unit-tested as a table of input/output pairs. Principle: show the content, hide the syntax, never flash raw markers.

| Case (at end of stream) | Rule |
|---|---|
| Unclosed `**bold` / `__bold` | Append the closer; render bold now. |
| Unclosed `*italic` / `_italic` | Append closer only if the opener is followed by a non-space and is not a list marker or intraword `_`. |
| Unclosed `~~strike` | Append closer. |
| Unclosed inline `` `code `` | Append a backtick; render as inline code now (fixes the raw "`comp" in `before/11-desktop-stream-6000ms.png`). |
| Lone trailing `*`, `_`, `~`, `` ` ``, `**` with nothing after | Drop from the render until the next token decides. |
| `[text` without `]` | Render `text` as plain text. |
| `[text](partial-url` | Render `text` styled as a link, not tappable until `)` arrives. |
| `![alt](partial` | Render nothing; reserve no space. Image appears when the URL closes (then with a fixed aspect box if width/height known). |
| Line that is only `#`...`######` | Hide until a heading character arrives. |
| Line that is only `-`, `*`, `+`, or `1.` | Hide the marker until item text arrives (prevents empty bullets). |
| Open code fence `` ```lang `` | **Auto-close the fence.** Render the code block frame immediately with the language label; code streams line by line inside it (section 6.2). Replaces today's `_stableRenderText`, which withholds the whole block and then pops 15 lines in at once (`before/40-harness-chatgpt-light-09s.png` to `-11s.png`). |
| Table: header line only | Hold the line back entirely until the separator row arrives, then render the table. |
| Table: separator row partial (`|---|--`) | Hold back. |
| Table: trailing partial row | Render completed cells of the row; the in-progress cell renders its text; missing cells render empty with the row height already reserved. |
| Open inline math `$x^2` | Render the raw TeX in `monoInline` `textTertiary` (no `$`); when `$` closes, cross-fade to typeset math over `fast`. |
| Open block math `$$...` | Render the block math frame (section 6.4) with the raw TeX in `mono` `textTertiary`; cross-fade to typeset math when `$$` closes. Never render literal `$$` (today: `before/43-harness-claude-dark-mobile-12s.png`). |
| Incomplete HTML tag `<det` | Hide until `>`. |
| Single `$` used as currency (`$5`) | Not math: the opener must be followed by a non-digit, non-space character and the closer preceded by non-space (Streamdown/KaTeX convention). |

Security (applies always, not only mid-stream): links and images honour `allowedLinkPrefixes` / `allowedImagePrefixes` (default `https://`, `http://`, `mailto:`); anything else renders as plain text. `javascript:` and `data:` URLs never become tappable. Raw HTML is not rendered unless `allowHtml: true`.

---

## 6. Block rendering

### 6.1 Block model and memoization

- Split the revealed text into top-level blocks at blank lines, fence-aware and math-aware (a blank line inside a fence or `$$` does not split).
- Every block except the last is complete: parse once, build once, cache by `(index, contentHash, brightness, textScale)`. The cache key includes brightness so a theme switch rebuilds (fixes gap G2).
- Engine decision: raise the floor to `gpt_markdown: ^1.3.0` and route through its incremental segment cache (and `SliverGptMarkdown` for long answers inside scroll views). Our layer adds what gpt_markdown lacks or does differently: `mend` (close syntax instead of holding the reveal back), streaming code frames, table width locking, the shared token look, the caret, and the pacing contract that matches the sibling chat UI.
- Only the last block is re-parsed per tick, after `mend`. Cost per frame is O(last block), not O(whole answer). Today the whole buffer is re-parsed through `GptMarkdown` on every tick.
- One render path. LaTeX is an inline and block component inside the markdown renderer, never a separate "LaTeX mode" that drops markdown. Today, as soon as the first `$...$` closes, `_buildLatexMarkdown` takes over and the code block, table and link revert to raw markdown source (`before/40-harness-chatgpt-light-13s.png` vs `-16s.png`).

### 6.2 Code blocks (shared look with sibling `CodeBlockView`)

- Frame: `codeBg`, 1px `codeBorder`, radius 12, vertical margin 12 (8 when first/last child).
- Header: 44px, language label `monoLabel` (JetBrains Mono 12/16, +0.2 tracking) `textTertiary` lowercase, 12 start padding; copy button 44x44 hit, 16px icon, `textTertiary`, copy to check swap for 1500ms. Today's gpt_markdown header is a pill label plus a round icon button on an M3-tinted fill (`before/40-harness-chatgpt-light-11s.png`; the tofu glyphs there are a harness font-config artefact, not a package bug).
- Code: JetBrains Mono 13.5/20, padding 14x16, no wrap, horizontal scroll, 24px right-edge fade mask when overflowing. Always LTR.
- **While streaming:** the frame appears as soon as the opening fence line is complete. Lines append inside it; the frame grows one line height at a time. Syntax highlighting runs on complete lines; the in-progress line renders in the base code colour and is highlighted when its newline arrives (no colour flicker on every token). The copy button is visible but disabled (40% opacity, semantics "Copy code, available when complete") until the fence closes.
- Default highlighter: the sibling's bundled highlighter and palettes. Consumers can still inject `codeBuilder`.

### 6.3 Tables

- Header row: weight 600, `surfaceSunken` fill. Cells padded 8 vertical, 12 horizontal. Horizontal 1px `border` hairlines only; no vertical rules; no outer box (today: black 1px grid, `before/40-harness-chatgpt-light-13s.png`).
- Container: horizontal scroll when wider than the column, with the same right-edge fade mask as code. Never shrink text to fit.
- **While streaming:** column widths are computed from the header and the first complete body row, then locked for the rest of the stream (cells wrap within their locked width). At stream end, widths are recomputed once, inside the same frame as the caret fade-out, so the only reflow is a single settle, not one per row.
- Numeric columns (all body cells parse as numbers) align to the end edge with tabular figures.

### 6.4 LaTeX

- Inline math is a `WidgetSpan` aligned to the text baseline, sized at 1.0 em of the surrounding text, colour `textPrimary`, weight 400. Today inline math drops onto its own line and renders smaller than body (`before/04-desktop-scroll-1.png`, `before/44-harness-claude-dark-mobile-22s.png`).
- Block math: `MathStyle.display`, centered, inside a frame of `codeBg` + 1px `codeBorder`, radius 12, padding 12x16, horizontal scroll when wider than the column. Vertical margin 12. No extra 24px blank gaps above and below (visible in `before/44-*`).
- Malformed TeX falls back to the raw source in `mono` `textTertiary` with a `danger`-coloured 2px start rule, and the widget never throws.

### 6.5 Markdown typography (shared scale)

Inherit the host font (`Theme.of(context).textTheme`); set size, height, weight, tracking only.

| Role | Size / line height | Weight | Tracking |
|---|---|---|---|
| `h1` | 20 / 28 | 600 | -0.2 |
| `h2` | 17.5 / 26 | 600 | -0.1 |
| `h3`-`h6` | 16 / 24 | 600 | 0 |
| `body` | 16 / 25 | 400 | 0 (dark +0.1) |
| `strong` | 16 / 25 | 600 | 0 |
| `mono` (code) | 13.5 / 20 | 400 | 0 |
| `monoInline` | 0.9 em | 400 | 0 |
| `monoLabel` | 12 / 16 | 400 | +0.2 |

Rhythm: paragraph gap 12; heading margin top 20 (first child 0), bottom 8; list item gap 4, indent 20, bullets `textSecondary`; blockquote 3px start rule (`border` light, `borderStrong` dark), 12 start padding, `textSecondary`, no fill; `hr` 1px `border`, 24 vertical margin; links `accent`, underlined.

The largest thing in an answer is a 20px heading. Today `# Heading 1` renders at about 34px and `hr` lines appear under headings (`before/04-desktop-scroll-1.png`); both go.

---

## 7. Reduced motion

When `MediaQuery.disableAnimationsOf(context)` is true (and when `animationsEnabled: false`):

- `streamFade`, `fast` and the math cross-fade resolve to `Duration.zero`.
- The caret is a static dot at full opacity (no pulse), still removed at stream end.
- Pacing still applies (the reveal is information, not decoration), but chunking coarsens to whole lines per 50ms window so the text changes less often.
- Typewriter and word-fade presets behave like `smoothFade` without fade.
- The trailing bottom-edge `ShaderMask` fade is removed entirely (it is replaced by per-run fade in any case).

Today there is no reduced-motion handling anywhere in `lib/`.

---

## 8. RTL and bidi

- Direction is detected per block from the first strong character (not per widget from "contains any Arabic"), so a mixed English answer with one Arabic quote keeps its LTR paragraphs.
- All paddings and alignments are directional (`EdgeInsetsDirectional`, `AlignmentDirectional`). Blockquote rule and list indent mirror.
- The caret sits at the end edge of the last line (left in RTL).
- Fade works for Arabic and Sorani: per-run opacity does not break shaping, unlike per-glyph widgets (the reason fade is disabled for Arabic today). Word units split on whitespace and ZWNJ is kept with its word.
- Code blocks and block math stay LTR inside RTL answers.
- Showcase font for RTL: Vazirmatn (shared with the sibling demo).

---

## 9. Selection, copy and semantics

- Wrap the rendered answer in `SelectionArea` by default (`selectable: true`). Settled blocks are selectable during the stream; the live block becomes selectable at stream end.
- "Copy" on code copies raw code without the fence. A `StreamingTextController.copyMarkdown()` helper returns the full source.
- Semantics: the answer is one `Semantics` node whose label updates only at stream end (plus once per completed block when `announceBlocks: true`), so screen readers are not flooded per token.
- Text scale: respect `MediaQuery.textScalerOf` up to 2.0 with no clipping and no fixed-height containers.

---

## 10. Showcase site spec (sells the package in 5 seconds)

Single-page Flutter web app (the example), same tokens, host font Geist, code JetBrains Mono, one accent `#2450D6` light / `#8AA8FF` dark, follows system theme on first load. Title tag "Streaming Markdown for Flutter" (today it is "example").

**Above the fold (desktop, 12-column grid, max width 1200):**
- Left, columns 1-4: package name in `monoLabel` `textSecondary`; headline, 2 lines max, 40/44 600: "LLM answers that stream like ChatGPT"; subtext, 20 words max, `textSecondary`: "Markdown, code, tables and math render as tokens arrive. No raw asterisks, no jumps, no lag."; install block `flutter pub add flutter_streaming_text_markdown` with copy; text link "GitHub".
- Right, columns 5-12: **the split view.** Left pane "Raw tokens" shows the actual `Stream<String>` chunks as they arrive, monospace, each chunk in a faint alternating background so burstiness is visible. Right pane "Rendered" shows `StreamingTextMarkdown` on the same stream. Auto-plays on load: a realistic answer with a heading, bold, a Dart code block, a 3-row table and one inline plus one block equation. Loops after 4s idle, pauses on hover.
- Under the split view, one control strip: **speed slider** "Model speed" 10 to 400 tok/s (default 60) that drives the fake model, not the reveal; a **burstiness** toggle (steady / bursty network); a **mode** segmented control (Smooth fade / Word / Typewriter / Instant); a replay button. The point: the rendered pane stays smooth at any model speed and burst pattern.

**Below the fold (single scroll, each section a different layout family):**
1. **"Half-written markdown, handled"**: a frozen-frame strip of 5 tiles, each showing the same mid-stream moment rendered naively (raw `**`, lone backtick, `$$`, `|---|`, empty bullet) versus by this package. Static, no motion.
2. **Stress test**: a button "Stream a 20,000-character answer" that plays a long, code-heavy answer at 200 tok/s with a live frame-time readout (p50 / p99 build ms from `SchedulerBinding.addTimingsCallback`) and a block count. This is the performance proof.
3. **RTL**: Arabic and Sorani answers streaming in Vazirmatn, side by side with English.
4. **Theming**: light/dark toggle plus 3 `StreamingTextTheme` presets, rendered on the same frozen answer.
5. **Code**: the 12-line snippet to wire an OpenAI or Anthropic SSE stream, with copy.

**Mobile (< 768):** single column: name, headline (32/36), subtext, install, then the split view stacked as tabs ("Rendered" default, "Raw tokens" second) at 440px height, then the control strip wrapped to two rows. The fixed theme toggle moves into the top bar; nothing floats over content (today it overlaps card controls, `before/24-mobile-dark-s3.png`). The package name wraps at underscores, never mid-word (today "..._mar / kdown", `before/20-mobile-dark-hero-midstream.png`).

**Copy rules:** no emoji in content or headings, no em dashes, no preset names that imply motion we removed (bouncy, dramatic). Card layouts keep a fixed height with text that fits (today the preset cards clip their descriptions, `before/20-*`).

**Layout stability:** every demo panel has a fixed height with internal scroll pinned to the bottom while streaming, so the page never shifts as text grows (today the hero card grows and pushes everything below it, `before/01-*` vs `before/02-*`).

---

## 11. Anti-patterns (do not ship)

1. Raw markdown syntax visible mid-stream, in any case listed in section 5.
2. A second render path that drops markdown when LaTeX, Arabic or a stream is present.
3. Withholding a whole block (code, table, math) and popping it in complete.
4. Fixed-rate reveal for stream input; reveal lagging more than about 400ms behind received text.
5. One `AnimationController` per character or per word.
6. Bottom-edge `ShaderMask` fades that dim whole lines rather than the newly arrived run.
7. `Colors.*` literals (blue LaTeX, red errors, white gradient stops) in default paths; `colorScheme.surface*` for code or table fills.
8. Caching built widgets across theme, text scale or direction changes.
9. Any animation that ignores `MediaQuery.disableAnimationsOf`.
10. `markdownEnabled: false` as the default of a package named "streaming text markdown".
11. Headings larger than 20px, `hr` under headings, full-grid black table borders.
12. Motion vocabulary beyond opacity (bounce, slide, blur, scramble) in presets.
13. Demo UI that floats controls over content, clips text in fixed cards, or grows and shifts the page while streaming.
