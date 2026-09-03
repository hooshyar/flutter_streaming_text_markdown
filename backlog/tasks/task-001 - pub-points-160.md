**Priority:** P1
**Component:** package-quality
**Origin:** award-quality goal, 2026-09-02

**Problem:** Currently 150/160 pub.dev points. Need to run `dart pub publish --dry-run`
and `pana` locally to find exactly which points are lost and fix each one.

**Acceptance criteria:**
- [x] `dart pub publish --dry-run` run, output captured
- [x] `pana` (via `dart pub global activate pana` or `dart run pana`) run locally, score breakdown captured
- [x] Every lost point identified with cause (e.g. missing platform support declarations, doc coverage, static analysis issues, example score, etc.)
- [x] Each fixable item fixed on main, committed
- [x] Re-run pana to confirm score improvement (target 160/160; note any point that's structurally unreachable, e.g. requires a wait period)

**Notes:** Don't guess — pana's own report is ground truth for what's lost.

**DONE 2026-09-02.** Cause: one INFO lint — `gpt_markdown`'s deprecated
`highlightBuilder` (10 pts off "Pass static analysis"). Fixed by migrating
internally to `inlineCodeBuilder`/`baselineWidgetSpan`, which then required
bumping the `gpt_markdown` lower bound from `^1.1.7` to `^1.2.0` to keep the
"compatible with dependency constraint lower bounds" check passing. Final:
160/160. Commit c3428a2.
