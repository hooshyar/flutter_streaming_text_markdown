# Award-quality plan

What it would take to push `flutter_streaming_text_markdown` to Flutter-Favorite /
award-winning quality, ranked by value-over-effort. Updated as items land —
see `backlog/tasks/` for execution tracking.

## Done (2026-09-02/03 session)

| Item | Result |
|---|---|
| pub.dev score | 150/160 → **160/160**. Sole cause of the gap: one INFO lint (`gpt_markdown`'s deprecated `highlightBuilder`). Fixed by migrating to `inlineCodeBuilder`/`baselineWidgetSpan` internally + bumping the `gpt_markdown` floor to `^1.2.0` (the old floor no longer resolved to a version with the new API, which broke pana's downgrade-compatibility check). |
| Issue #17 | Fixed & closed — `.chatGPT()`/`.claude()`/`.typewriter()`/`.instant()` now accept optional `fadeInDuration`/`fadeInCurve`/`typingSpeed` overrides, backward compatible. |
| Dartdoc coverage | 80% → **100%** (199/199 public API elements). `public_member_api_docs` lint enabled permanently to prevent regressions. |
| Dependency freshness | Verified via `flutter pub outdated` (repo + example) — all direct/dev deps already at latest stable; remaining "outdated" entries are Flutter-SDK-pinned transitives, not actionable. |
| WASM/Web compat | `flutter build web --wasm` succeeds cleanly on the example app; pana independently reports "WASM-ready" and 20/20 platform-support points (all 6 platforms). |

## Remaining, ranked by value ÷ effort

### High value, low effort

1. **Long-stream performance benchmark test** (`backlog/tasks/task-006`).
   No test currently proves the package holds up on a 50k+ character LLM
   transcript — the exact workload this package exists for. A single
   `flutter_test` pumping a large stream through `StreamingTextMarkdown` and
   asserting bounded completion time is cheap to write and directly backs
   the "performance on very long streams" claim.
2. **Add the WASM build + pana score to CI.** Right now `.github/workflows/`
   only runs analyze/format/test/dry-run. A regression in WASM compat or pub
   score would go unnoticed until a manual check like this session's. Add a
   `flutter build web --wasm` step (example app) and, optionally, a
   `pana --json` score-floor check to the existing CI job. Low effort, high
   leverage since it's the one thing standing between "we verified it once"
   and "it stays true."
3. **CHANGELOG "Unreleased" → versioned release** (`task-008`). Ships
   everything above to actual pub.dev users. Low effort once the rest is
   done; high value because none of this compounds until it's published.

### Medium value, medium effort

4. **Accessibility audit.** `StreamingText` exposes `semanticsLabel` and
   `selectable`, but there's no test asserting screen-reader semantics are
   correct mid-animation (e.g. that partially-typed text doesn't confuse
   TalkBack/VoiceOver, or that the cursor glyph isn't read aloud). Worth a
   focused pass with `flutter_test`'s `SemanticsTester`.
5. **Test-coverage measurement.** No `flutter test --coverage` baseline is
   currently tracked. Running it once and identifying any untested branches
   in `streaming_text.dart` (the largest file, ~75KB) would catch gaps the
   existing 108 tests don't surface. Consider wiring `lcov` output into CI
   with a badge.
6. **RTL/Arabic/Kurdish correctness beyond Arabic-only detection.** The
   Unicode-range detection in `StreamingText` covers Arabic script (which
   Kurdish Sorani also uses), but there's no test asserting Kurdish-specific
   text (e.g. containing ک ,گ ,ڕ ,ژ ,ڵ — letters outside standard Arabic)
   triggers the same RTL/fade-disable path. Cheap to add given the existing
   Arabic test harness.

### Higher effort / lower immediate leverage

7. **Example app polish pass.** Not audited in depth this session — worth a
   dedicated look at whether it demonstrates every preset, the controller
   API, LaTeX, and error states (e.g. a stream that throws) in one place a
   new user can copy from.
8. **Flutter Favorite nomination itself** is a Google editorial process, not
   something this repo can force — the above items are prerequisites, not a
   guarantee. Once pub score/docs/tests/demo are all solid, it's worth
   flagging to Hooshyar as a manual submission step rather than automating.
9. **API ergonomics beyond issue #17.** No other open ergonomics complaints
   exist right now (0 other open issues/PRs). Revisit if new issues surface.

## Notes

- Every item above should be verified the same way this session verified
  pub points: run the actual tool (`pana`, `dart doc`, `flutter build web
  --wasm`, `flutter pub outdated`) rather than trusting prior knowledge of
  what's "probably" true — several of the above (WASM, deps) turned out to
  already be solved, and the dartdoc fix itself introduced a new pana
  regression (dependency lower-bound) that only a re-run caught.
