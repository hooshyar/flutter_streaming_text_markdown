**Priority:** P1
**Component:** api
**Origin:** GitHub issue #17 (opened 2026-07-27)

**Problem:** User wants `fadeInDuration`, `fadeInCurve`, and `typingSpeed` to be
passable on the `StreamingTextMarkdown.chatGPT()` convenience constructor instead of
being hardcoded to the preset defaults.

**Acceptance criteria:**
- [ ] `.chatGPT()` (and check other presets: `.claude()`, `.typewriter()`, `.instant()`, `.fromPreset()` for the same gap) accepts optional overrides for `fadeInDuration`, `fadeInCurve`, `typingSpeed` that fall back to the preset default when null
- [ ] Backward compatible — no breaking change to existing call sites (flutter_gen_ai_chat_ui depends on this)
- [ ] Regression test added covering override behavior
- [ ] `flutter analyze` + `flutter test` clean
- [ ] Reply on GitHub issue #17 with explanation + link to the commit that fixes it, then close it
- [ ] CHANGELOG.md entry added

**Notes:** Use `gh issue comment 17` / `gh issue close 17` after the fix ships.
