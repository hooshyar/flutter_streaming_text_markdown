**Priority:** P2
**Component:** docs/planning
**Origin:** award-quality goal, 2026-09-02

**Problem:** Need a written, ranked plan of what would push this package to
Flutter-Favorite / award-winning quality, so cheap high-value items get done now and
expensive ones are tracked for later.

**Acceptance criteria:**
- [x] `doc/AWARD-PLAN.md` created: list of improvements ranked by value-over-effort
      (API ergonomics, doc coverage, README/demo quality, example app polish, wasm/web
      compat, perf benchmarks, accessibility, RTL/Arabic/Kurdish correctness, test coverage)
- [x] Each item has a rough effort estimate and expected impact
- [x] Cheap/high-value items (effort: small) get implemented immediately as part of this task or spun into their own follow-up task files
- [x] Committed to main

**DONE 2026-09-03.** `doc/AWARD-PLAN.md` written with a "Done" table (pub
score, issue #17, dartdoc, deps, wasm — all landed this session) and a
ranked remaining list. Implemented the one clearly-cheap item immediately:
added a `wasm-build` job to `.github/workflows/ci.yml` that runs
`flutter build web --wasm` on the example app every push/PR, so WASM compat
can't silently regress. Remaining items (perf benchmark test, accessibility
audit, test-coverage measurement, Kurdish-specific RTL test, example app
polish, pana-score CI gate) tracked in the plan doc / existing backlog
tasks for follow-up ticks.
