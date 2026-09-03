**Priority:** P3
**Component:** performance
**Origin:** award-quality goal, 2026-09-02

**Problem:** No test-suite evidence of performance on very long streams (LLM chat
transcripts can be tens of thousands of characters). Need benchmarks to catch
regressions and demonstrate quality.

**Acceptance criteria:**
- [x] Test added that streams/animates a very large text (e.g. 50k+ chars) through
      `StreamingText`/`StreamingTextMarkdown` and asserts it completes within a sane
      time bound / without exceptions, using `flutter_test`'s frame pumping
- [x] Confirms fade-in-per-character suppression under `stream != null` holds (memory safety) per CLAUDE.md
- [x] Test committed and passing in `flutter test`

**DONE 2026-09-03.** `test/long_stream_performance_test.dart` — two tests:
(1) a 50k+ char static text with a large `chunkSize` completes within a
400-pump budget; (2) a 60k+ char `stream:` payload (fed across 20 chunks)
with `fadeInEnabled: true` completes within the same pump budget, proving
the `stream != null` per-character fade-in suppression (`_fadeInAllowed`
checks `widget.stream == null`, confirmed by reading
`lib/src/streaming/streaming_text.dart`) holds at real LLM-transcript scale
— a controller-per-glyph leak would time out or blow the pump budget well
before completing. Both run in ~2s wall-clock (fake async clock via
`tester.pump`, not real delays). 110/110 tests pass overall.
