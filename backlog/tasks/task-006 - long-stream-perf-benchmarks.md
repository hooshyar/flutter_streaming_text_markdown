**Priority:** P3
**Component:** performance
**Origin:** award-quality goal, 2026-09-02

**Problem:** No test-suite evidence of performance on very long streams (LLM chat
transcripts can be tens of thousands of characters). Need benchmarks to catch
regressions and demonstrate quality.

**Acceptance criteria:**
- [ ] Test added that streams/animates a very large text (e.g. 50k+ chars) through
      `StreamingText`/`StreamingTextMarkdown` and asserts it completes within a sane
      time bound / without exceptions, using `flutter_test`'s frame pumping
- [ ] Confirms fade-in-per-character suppression under `stream != null` holds (memory safety) per CLAUDE.md
- [ ] Test committed and passing in `flutter test`
