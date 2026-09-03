**Priority:** P2
**Component:** docs
**Origin:** award-quality goal, 2026-09-02

**Problem:** Flutter Favorite / award-tier packages have complete, example-rich dartdoc
on every public API member. Need an audit of current coverage and gaps filled.

**Acceptance criteria:**
- [x] Audit public API surface (lib/flutter_streaming_text_markdown.dart barrel + exported classes) for missing or thin `///` doc comments
- [x] Every public class, constructor, and non-trivial public member has a doc comment; widgets/config classes include a short usage example where useful
- [x] `dart doc` (or pana's doc-coverage check) run to confirm improvement
- [x] No behavior changes — docs only

**DONE 2026-09-03.** Used `dart doc . --output <tmp>` + parsed `index.json`'s
`desc` field (empty = undocumented) to get pana's exact undocumented-symbol
list (more reliable than `public_member_api_docs` alone, which misses
implicit constructors). Documented all 40 pana-flagged symbols plus 13 more
the lint caught once actually enabled (enum values in `AnimationSpeed` and
`SegmentType`, `TextSegment` fields, `StreamingShimmer` constructor). Also
fixed one dartdoc warning (unresolved `[_updateProgress]` doc reference).
`LLMAnimationPresets` and `StreamProvider` got explicit documented
constructors (private `._()` for the static-only presets class, `const`
default for the abstract provider). Enabled `public_member_api_docs: true`
permanently in `analysis_options.yaml` to prevent future regressions.
Result: dart doc 0 warnings, pana 199/199 (100.0%) API elements documented,
score still 160/160, 108/108 tests pass.
