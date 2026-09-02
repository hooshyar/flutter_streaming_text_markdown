**Priority:** P1
**Component:** package-quality
**Origin:** award-quality goal, 2026-09-02

**Problem:** Currently 150/160 pub.dev points. Need to run `dart pub publish --dry-run`
and `pana` locally to find exactly which points are lost and fix each one.

**Acceptance criteria:**
- [ ] `dart pub publish --dry-run` run, output captured
- [ ] `pana` (via `dart pub global activate pana` or `dart run pana`) run locally, score breakdown captured
- [ ] Every lost point identified with cause (e.g. missing platform support declarations, doc coverage, static analysis issues, example score, etc.)
- [ ] Each fixable item fixed on main, committed
- [ ] Re-run pana to confirm score improvement (target 160/160; note any point that's structurally unreachable, e.g. requires a wait period)

**Notes:** Don't guess — pana's own report is ground truth for what's lost.
