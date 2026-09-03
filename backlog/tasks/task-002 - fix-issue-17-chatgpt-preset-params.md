**Priority:** P1
**Component:** api
**Origin:** GitHub issue #17 (opened 2026-07-27)

**Problem:** User wants `fadeInDuration`, `fadeInCurve`, and `typingSpeed` to be
passable on the `StreamingTextMarkdown.chatGPT()` convenience constructor instead of
being hardcoded to the preset defaults.

**Acceptance criteria:**
- [x] `.chatGPT()` (and check other presets: `.claude()`, `.typewriter()`, `.instant()`, `.fromPreset()` for the same gap) accepts optional overrides for `fadeInDuration`, `fadeInCurve`, `typingSpeed` that fall back to the preset default when null
- [x] Backward compatible — no breaking change to existing call sites (flutter_gen_ai_chat_ui depends on this)
- [x] Regression test added covering override behavior
- [x] `flutter analyze` + `flutter test` clean
- [x] Reply on GitHub issue #17 with explanation + link to the commit that fixes it, then close it
- [x] CHANGELOG.md entry added

**DONE 2026-09-02.** Commit c3428a2, issue closed with comment linking it.
`.fromPreset()` intentionally skipped — callers already pass a full custom
`StreamingTextConfig` there, so it has no gap to fix.

**Notes:** Use `gh issue comment 17` / `gh issue close 17` after the fix ships.
