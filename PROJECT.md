---
name: Flutter Streaming Text Markdown
client: Datacode (open source)
status: active
owner: Hooshyar
team: [Hooshyar]
stack: [Flutter, Dart, gpt_markdown, flutter_math_fork]
repo: hooshyar/flutter_streaming_text_markdown
prod: https://pub.dev/packages/flutter_streaming_text_markdown
updated: 2026-10-03
---

# Flutter Streaming Text Markdown

## Intent
Flutter package that streams LLM output (ChatGPT, Claude, Gemini) into live markdown with typewriter or fade reveal, LaTeX, RTL and pause/skip control. It tolerates half-written markdown (open code fences, partial tables) without flashing raw syntax, and it is the rendering engine under flutter_gen_ai_chat_ui. Standing goal (conductor NOTES.md, 2026-09-02): award-grade quality, 160/160 pub points, issues and PRs answered, dependencies on latest stable, releases cut.

## Current focus
- 1.11.0 is published and tagged (`v1.11.0`). The next patch release (Hooshyar's go) carries the updated pubspec description to pub.dev.
- Task-023, the only open task: show flutter_dot_loader as the "waiting for first token" indicator in the example and README. Blocked until flutter_dot_loader 1.1.0 is published; example-only dependency, never added to the package pubspec.
- Hold 160/160 pub points and the CI gates: coverage floor 90% (measured 94.9%), weekly upgrade plus pana job, WASM build check.

## Not doing
- Per DESIGN.md: no per-character typewriter by default (opt-in preset only), no blur or slide effects, no lingering semi-transparent text.
- The default markdown typography layer (B2) was built and then reverted on purpose (descope); it stays in git history.
- Static markdown that never streams (use flutter_markdown_plus or gpt_markdown) and full chat screens (use flutter_gen_ai_chat_ui) are out of scope (README).

## How to run and verify
- `flutter pub get`, `flutter analyze`, `flutter test` (feature folders under test/: engine, widget, stream, controller, markdown, a11y, render, perf, api), `dart format lib/ test/`, `dart pub publish --dry-run`.
- Coverage: `flutter test --no-dds --coverage --exclude-tags benchmark`, then `dart run tool/check_coverage.dart 90` (the CI floor; without `--no-dds` the run can stall). Known flake: markdown_fade_verify3_test "a block quote caret=true" under heavy machine load.
- Example: `cd example && flutter pub get && flutter run` (only when asked). Live demo: https://hooshyar.github.io/flutter_streaming_text_markdown/ (pages.yml, on pushes to main).
- Release: a `v*` tag triggers publish.yml (pub.dev OIDC). Check workflow triggers before pushing any tag and tag only after Hooshyar's go and a live check. 1.11.0 went out by local `dart pub publish` on 2026-10-02 per notes. TODO: confirm whether automated publishing works now.

## Decisions
- 2026-09-28: B2 default typography layer reverted as a deliberate descope (commit 059a256).
- 2026-10-02: docs/ and backlog/ excluded from the pub archive; CI coverage floor set at 90%; Windows-safe filename CI guard added.
- 2026-10-02: 1.11.0 shipped with no breaking changes: RevealEngine core, gpt_markdown 1.3 migration, `CodeBlockView` and `CodeBlockTheme`.
