# flutter_streaming_text_markdown — Improvement Plan (2026-09)

Research date: 2026-09-24. Planning only; this document changes no library code.
Execution is tracked in `backlog/tasks/` under the `improvement-plan-2026-09` label.
The earlier `doc/AWARD-PLAN.md` (2026-09-02/03) is complete; every task-001 to task-014 is Done.

---

## 1. Current state snapshot

### pub.dev metrics (pub.dev API, 2026-09-24)

| Metric | Value |
|---|---|
| Latest version | 1.10.1 (published 2026-09-03) |
| Pub points | **150 / 160** (was 160/160 at 1.10.0 and at 1.10.1 publish) |
| Likes | 52 |
| Downloads (30d) | 12,893 |
| GitHub | 38 stars, 11 forks, 0 open issues, 0 open PRs |
| Tags | all 6 platforms, WASM-ready, Dart 3 compatible, MIT |
| Reverse deps | `flutter_gen_ai_chat_ui` 2.19.1 (our own chat UI package) depends on it |

### Why 10 pub points are missing

"Pass static analysis" is at 40/50. pub.dev re-analysed the package about 2026-09-22 (Pana 0.23.19,
Flutter 3.47.4) and resolved **`gpt_markdown` 1.3.0**, which was released 2026-09-20 and deprecated a set
of APIs that we forward. pana reports 4 INFO issues, all in `lib/src/streaming/streaming_text.dart`
(`_buildSimpleMarkdown`, around lines 2140-2161):

| Our usage | Deprecated in gpt_markdown 1.3.0 | Replacement |
|---|---|---|
| `sourceTagBuilder:` (L2152) | yes | `inlineSourceTagBuilder` (`InlineSpan Function(SourceTagBuildDetails)`) |
| `linkBuilder:` (L2158) | yes | `inlineLinkBuilder` (`InlineSpan Function(LinkBuildDetails)`) |
| `components:` | yes | `blockComponents` |
| `inlineComponents:` | yes | `inlinePatterns` / `inlineDirectives` |

This is the same kind of drift that task-001 fixed for `highlightBuilder` at 1.2.0. Nothing in the repo
changed. The upstream release alone cost the points, and no CI job runs between our pushes to catch it.
Our root `pubspec.lock` is untracked (correctly, for a library), so the next push would have shown the
problem, but nothing has been pushed since 2026-09-03.

**Side effect to note:** per gpt_markdown's `MIGRATION.md`, passing `components` or `inlineComponents`
at all, even as an empty list, switches `GptMarkdown` back to the legacy regex parser. That parser has no
segment cache, no span-level reveal, and no lazy sliver rendering. Our issue #13 answer told users to use
`components` for per-element styling, so those users are pushed onto the slow path.

**Fix (TASK-015):** migrate to the four replacements, adapting our existing public builder signatures
through `baselineWidgetSpan`/`WidgetSpan` so the change is non-breaking. Bump `gpt_markdown` to `^1.3.0`.
Add `blockComponents`/`inlinePatterns`/`inlineDirectives` pass-throughs and `@Deprecated` our own
`components`/`inlineComponents`. Then run `flutter pub downgrade && flutter analyze` (the lower-bound
check) and `pana`, and release 1.11.0.

### Analyzer, tests, coverage (local, Flutter 3.47.5 / Dart 3.13.4)

- `flutter analyze` locally: clean, but only because the local lock still resolves gpt_markdown **1.2.1**.
  Against 1.3.0 it gives the 4 INFOs above.
- Tests: 114 `test`/`testWidgets` cases across 14 files. Coverage: see §1.1.
- CI (`.github/workflows/ci.yml`): format, analyze, test, publish dry-run, example analyze and test, and a
  WASM build. It runs on push/PR only, with **no `schedule:` trigger**, which is why the upstream drift
  went unnoticed.

### Dependencies: current constraint vs latest stable (pub.dev, 2026-09-24)

| Package | Our constraint | Locally resolved | Latest stable | Status |
|---|---|---|---|---|
| gpt_markdown | ^1.2.0 | 1.2.1 | **1.3.0** (2026-09-20) | **Upgrade + migrate (P0)** |
| flutter_math_fork | ^0.7.4 | 0.7.4 | 0.7.4 | current |
| characters | >=1.4.0 <2.0.0 | 1.4.1 | 1.4.1 | current |
| flutter_lints (dev) | ^6.0.0 | 6.0.0 | 6.0.0 | current |
| example: url_launcher | ^6.3.2 | current | current | current (transitives `url_launcher_android` 6.3.33, `platform` 3.2.0 lock-bumpable) |
| SDK floor | `sdk >=3.0.0`, `flutter >=3.10.0` | — | — | **Inaccurate:** gpt_markdown >=1.2.0 needs Dart >=3.7, and 1.2.1 needs Flutter >=3.32. Declare the real floor. |

About the markdown engine: `flutter_markdown` is **discontinued** (replacedBy `flutter_markdown_plus`
1.0.12). We already moved off it to `gpt_markdown`, which is now the most-used AI-focused renderer
(323 likes, 155k downloads/30d, 160/160). 1.3.0 added a single-pass parser (`plusparse`), segment caching
(31x faster per streaming chunk at 12 KB), `SliverGptMarkdown`, its own character/block reveal
animations, 200-language code highlighting with a copy button, a component style sheet, and
structural builders (`headingBuilder`, `tableBuilder`, `blockQuoteBuilder`, list builders, and more).
**gpt_markdown is still the right base.** Switching to `flutter_markdown_plus` would lose LaTeX, the
AI-oriented edge-case handling and the new streaming pipeline. The risk is strategic rather than
technical: gpt_markdown now ships a built-in streaming reveal, so our value has to sit above it (see P2-3).

### 1.1 Coverage

Line coverage from `flutter test --coverage` (lib/ only):

Not measured yet. The `flutter test --coverage` run on 2026-09-24 took more than 35 minutes on a heavily loaded machine (other sessions were compiling in parallel) and had not finished when this was committed. The earlier untracked `coverage/lcov.info` is from 2026-08-25 and predates v1.10.x. TASK-022 establishes the baseline in CI.

---

## 2. Competitor matrix

Metrics are from the pub.dev API on 2026-09-24. Features come from each package's README.

| Package | Ver (date) | Likes | DL/30d | Points | Engine | Positioning / notable features |
|---|---|---|---|---|---|---|
| **flutter_streaming_text_markdown** | 1.10.1 (09-03) | 52 | 12.9k | 150 | gpt_markdown | Typing/fade presets (ChatGPT/Claude/typewriter/bouncy), `Stream<String>` input, controller (pause/resume/skip/restart), RTL auto-detect incl. Sorani, real LaTeX, TTFT shimmer, trailing fade, fence withholding |
| gpt_markdown | 1.3.0 (09-20) | 323 | 155k | 160 | own (plusparse) | Now ships **its own streaming reveal**, block animations, segment cache, `SliverGptMarkdown`, highlight + copy, style sheet, reduced-motion, a11y announcement fix |
| flutter_markdown_plus | 1.0.12 (07-10) | 144 | 648k | 160 | markdown | Official successor of flutter_markdown. No streaming features. Used by `flutter_ai_toolkit` |
| markdown_widget | 2.3.2+8 (2025-04) | 411 | 6.5k | 160 | markdown | TOC, highlighting. Stale for 17 months |
| flutter_md | 0.2.0 (08-05) | 61 | 8.0k | 160 | own | Incremental `StreamingMarkdownParser` (frozen blocks, live tail) |
| flutter_markdown_stream | 0.5.0 (08-27) | 4 | 2.5k | 160 | flutter_markdown_plus | **Sanitizer for unclosed bold/italic/code/fence/links/tables/LaTeX**, one-frame debounce, token **smoothing**, **per-word fade**, **stick-to-bottom AutoScroll**, CodeBlockView with copy, incremental parse, 8 a11y-friendly cursors, controller |
| streamdown | 0.1.1 (05-28) | 7 | 108 | 160 | own | Append-only AST, provisional fences/table rows, stable widget keys, "188x faster" benchmark, live side-by-side demo |
| flutter_smooth_markdown | 0.10.0 (09-18) | 15 | 2.5k | 140 | own | Streaming, LaTeX, Mermaid, footnotes, editor, AI chat blocks (thinking/artifacts) |
| hyper_render | 1.9.1 (09-07) | 19 | 445 | 160 | own RenderObject | HTML+MD, crash-free selection on huge docs, frame-aligned throttled LLM streaming |
| animated_streaming_markdown | 0.4.0 (09-09) | 3 | 274 | 140 | Tree-sitter | Selection controller, rich clipboard, lazy sliver selection |
| flowtoken_flutter | 0.1.2 (07-26) | 0 | 34 | 150 | gpt_markdown | FlowToken port: animations for streaming LLM text |
| animated_text_kit | 4.3.0 | 5682 | 121k | 160 | none | Generic text animations with no markdown (adjacent audience for "typewriter" search) |
| typewritertext | 3.0.9 (2024) | 230 | 5.2k | 160 | none | Plain typewriter |

### Feature gaps vs the field

| Capability | Us | Best-in-class | Gap |
|---|---|---|---|
| Incremental parse on long outputs | Rebuilds `GptMarkdown` with the full text every tick. 1.3.0's segment cache helps only if we are on plusparse (not while `components` is passed) | streamdown, flutter_md, gpt_markdown 1.3 | **Medium**: fix via TASK-015, then measure (TASK-017) |
| Partial syntax (unclosed fence) | Withholds an odd ``` fence | flutter_markdown_stream (fence, bold, italic, strike, inline code, links, tables, LaTeX) | **High**: we only cover fences |
| LaTeX | Real (flutter_math_fork) | parity | none |
| Syntax highlighting + copy | Whatever gpt_markdown's default code block does, but `codeBuilder` overrides it | gpt_markdown 1.3 (200 langs + copy), flutter_markdown_stream CodeBlockView | Low: demo/document it, forward `onCodeCopy` |
| Per-element styling | Only via deprecated `components` | gpt_markdown `styleSheet` + structural builders | **High**: issue #5/#13 users are on a deprecated path |
| Selection/copy | `selectable` on `StreamingText` only, **not exposed on `StreamingTextMarkdown`** | hyper_render, animated_streaming_markdown | Medium |
| RTL | Auto-detect Arabic/Sorani, Directionality wrap | parity or ahead | none (strength) |
| a11y / reduced motion | No `MediaQuery.disableAnimations` handling; no semantics tests mid-stream | gpt_markdown 1.3 (reduced motion, no announcement storms), flutter_markdown_stream cursors with ExcludeSemantics | **High** for an award-quality claim |
| Word fade / token smoothing | Char/word typing, fade, trailing fade; no burst smoothing | flutter_markdown_stream (smooth by default, `wordFadeIn`) | Medium |
| Chat auto-scroll | `autoScroll` wraps its own ScrollController | stick-to-bottom that disengages when the user scrolls up | Medium |
| Controller API | pause/resume/skip/restart, progress | parity | none (strength) |
| Live demo | GitHub Pages demo exists | streamdown has a side-by-side vs flutter_markdown | Low: add a comparison page |

---

## 3. Prioritized plan

Effort: S (< half a day), M (1-2 days), L (3+ days).

### P0: restore score and stop silent regressions

**P0-1. Restore 160/160: migrate off gpt_markdown 1.3.0 deprecations** (TASK-015, M)
Why: we are losing 10 points today, and users who pass `components` are forced onto the legacy slow parser.
Acceptance:
- `gpt_markdown: ^1.3.0`. `environment` states the true floor (Dart >=3.7, Flutter >=3.32 or whatever gpt_markdown 1.3.0 resolves to).
- No use of `sourceTagBuilder`, `linkBuilder`, `components`, `inlineComponents`, `highlightBuilder` or `incremental` in lib. The existing public builder params keep working via span adapters (tests prove each one still renders).
- New pass-throughs `blockComponents`, `inlinePatterns`, `inlineDirectives`. Our `components`/`inlineComponents` are `@Deprecated` with a message pointing to them, and still forwarded behind a documented `// ignore: deprecated_member_use` only if we must keep them working.
- `flutter pub upgrade && flutter analyze` is clean, `flutter pub downgrade && flutter analyze` is clean, and `pana .` reports 160/160.
- CHANGELOG entry, release 1.11.0 via tag, pub.dev shows 160/160 after re-analysis.

**P0-2. Weekly scheduled CI with upgraded deps + pana score floor** (TASK-016, S)
Why: this is the second time an upstream release has silently cost us 10 points, and nothing between our releases re-checks the package.
Acceptance:
- `ci.yml` (or a new `nightly.yml`) has `schedule: cron` (weekly) plus `workflow_dispatch`, runs `flutter pub upgrade` and then analyze/test.
- A job runs `dart pub global activate pana && pana --json --no-warning .` and fails if `grantedPoints < 160`.
- A failure is visible (the default GitHub failure email is enough; optionally a `conductor-notify` hook).
- Also run `flutter pub downgrade && flutter analyze` to guard the lower-bound check.

**P0-3. Fix stale README headline and GitHub metadata** (TASK-020, S)
Why: the README's top section still says "🆕 v1.9.1" (two releases old). The GitHub repo description starts with a typo ("erfect for LLM Applications!"), and the homepage points to dilacode.com instead of the live demo. These are the first things a visitor sees.
Acceptance: README "What's new" reflects the current version (or is removed in favour of CHANGELOG). `gh repo edit --description` is fixed. `homepage` points to the live demo. The repo topics include `markdown`, `llm`, `streaming`, `chatgpt`, `flutter-package`.

### P1: close the gaps competitors market

**P1-1. Forward gpt_markdown 1.3's style sheet and structural builders (per-element styling)** (TASK-018, M)
Why: this revisits issues #5 and #13 properly. gpt_markdown 1.3 exposes `styleSheet`, `inlineCodeStyle`, `headingBuilder`, `tableBuilder`, `blockQuoteBuilder`, `orderedListBuilder`/`unOrderedListBuilder`, `hrBuilder`, `checkboxBuilder`, `onCodeCopy`, `onImageTap` and `onSourceTagTap`. We forward none of them, and users must import gpt_markdown directly for types.
Acceptance: each is exposed on `StreamingTextMarkdown` and `StreamingText` (and presets) and forwarded, the needed types are re-exported, there is one widget test per builder, and the README has a "Per-element styling" section with an example. Update the answer on #13.

**P1-2. Partial-syntax sanitizer beyond code fences** (TASK-019, M)
Why: flutter_markdown_stream and streamdown sell flicker-free handling of unclosed syntax. We only withhold an odd ``` fence (`_stableRenderText`).
Acceptance: a table-driven test matrix of mid-stream prefixes (`**bol`, `*ita`, `` `code ``, `[link](htt`, `| a | b |\n|--`, `$x^`, `~~st`, nested list, header `##`) asserts there is no raw-marker flash, no exception, and a monotonically growing visible text length. Fixes go in a pure-Dart helper with unit tests. Behaviour is unchanged once the stream completes.

**P1-3. Accessibility: reduced motion, semantics, selection on the top-level widget** (TASK-021, S-M)
Why: an award-quality claim needs this. gpt_markdown 1.3 already fixed announcement storms and honours reduced motion, and we don't.
Acceptance: `MediaQuery.disableAnimations == true` renders instantly (tested). `StreamingTextMarkdown` exposes `selectable` and `semanticsLabel`. A cursor/shimmer is excluded from semantics. A `SemanticsTester`-style test shows mid-stream semantics don't emit per-character updates. `meetsGuideline(textContrastGuideline)` passes on the example screen.

**P1-4. Long-stream performance benchmark vs gpt_markdown 1.3** (TASK-017, M)
Why: we rebuild the whole markdown tree every typing tick. We need numbers on 12 KB/50 KB outputs after TASK-015 (plusparse enabled), and we should decide whether to offer a sliver or lazy mode for very long docs.
Acceptance: a benchmark test (or `integration_test` with `traceAction`) records average and p90 frame build time at 12 KB and 50 KB for (a) our widget and (b) bare `GptMarkdown` fed the same stream. Results go in `docs/` and the README. Any >2x regression vs bare GptMarkdown gets a follow-up fix task.

**P1-5. Coverage in CI + badge** (TASK-022, S)
Why: there is no tracked baseline. `streaming_text.dart` is 2,264 lines, and its untested branches are where the recent bugs (013/014) came from.
Acceptance: CI runs `flutter test --coverage` and uploads lcov (Codecov or a shields badge from `lcov`). The README has a badge. New tests lift lib line coverage to >= 85% (see the §1.1 baseline).

**P1-6. Discoverability** (TASK-020 covers metadata. Content: S-M each)
- Rewrite the pubspec `description` for search. Currently it says "beautiful LLM text streaming", which misses the "typewriter", "ChatGPT/Claude/Gemini", "AI chat" search terms; keep it under 180 chars.
- README comparison section: "When to use this vs raw gpt_markdown / flutter_markdown_plus". Be honest about the value-add: presets, controller, RTL, `Stream<String>` input, TTFT shimmer, LaTeX.
- A side-by-side "raw GptMarkdown vs this package" page in the live demo, as streamdown does.
- Make sure the Flutter Gems listing (ChatGPT/LLM category) is current. Publish one dev.to/Medium post on streaming markdown in Flutter.

### P2: differentiate

**P2-1. Token smoothing + per-word fade mode** (M): pace bursty token arrivals into an even cadence, with an opacity-only word fade for `stream:` mode. Competitors now default to this.
**P2-2. Stick-to-bottom chat auto-scroll** (M): follow the bottom, disengage when the user scrolls up, re-engage at the bottom. Also useful for `flutter_gen_ai_chat_ui`.
**P2-3. Strategic: build on gpt_markdown 1.3's reveal engine** (L): gpt_markdown now animates by itself (`animation`, `charactersPerSecond`, `revealFadeSeconds`, block animations). Evaluate delegating markdown-mode animation to it (fewer rebuilds, span-level reveal). Keep our presets/controller/RTL/shimmer/LaTeX layer as the value-add. Could be a 2.0.
**P2-4. Split `streaming_text.dart` (2,264 lines)** (L): separate typing engine, markdown render, LaTeX render and fade layers, with no behaviour change. This lowers the bug rate seen in tasks 013/014.
**P2-5. Housekeeping** (S): remove stale `doc/remember.txt`, `doc/tasks.md`, `doc/context.md` (versions from 2024), and add `docs/` to `.pubignore` so this plan isn't shipped in the pub archive.
**P2-6. Code-block UX** (S): demo gpt_markdown 1.3's built-in highlighting and copy button, and forward `onCodeCopy` (partly in P1-1).

---

## 4. Issues/PR patterns (GitHub)

0 open issues and 0 open PRs. All 13 issues are closed. Recurring themes in the closed ones:
- Styling/customization (#5, #10, #13, #17): the most frequent ask, which drives P1-1.
- Stream/animation correctness (#1, #3, #11, #12): now well covered by tests (stream_mode_v191, fence stability).
- Release cadence questions (#14) and a demo request (#7): addressed with the live demo and auto-publish.
- External PRs: #15 (merged, `completeAnimationOnTap`) and #9 (closed, grapheme-cluster resume index; it was superseded).

## 5. Sources

- pub.dev score API and page: https://pub.dev/packages/flutter_streaming_text_markdown/score
- gpt_markdown 1.3.0 CHANGELOG + MIGRATION.md (pub cache, `dart pub cache add gpt_markdown --version 1.3.0`)
- Competitor READMEs on pub.dev: flutter_markdown_stream, streamdown, flutter_smooth_markdown, hyper_render, gpt_markdown, animated_streaming_markdown, flutter_md
- https://dev.to/jay_limbani_5de2aceb239f0/the-append-only-ast-trick-that-makes-flutter-ai-chat-actually-smooth-1c00
