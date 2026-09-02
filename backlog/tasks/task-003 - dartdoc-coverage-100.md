**Priority:** P2
**Component:** docs
**Origin:** award-quality goal, 2026-09-02

**Problem:** Flutter Favorite / award-tier packages have complete, example-rich dartdoc
on every public API member. Need an audit of current coverage and gaps filled.

**Acceptance criteria:**
- [ ] Audit public API surface (lib/flutter_streaming_text_markdown.dart barrel + exported classes) for missing or thin `///` doc comments
- [ ] Every public class, constructor, and non-trivial public member has a doc comment; widgets/config classes include a short usage example where useful
- [ ] `dart doc` (or pana's doc-coverage check) run to confirm improvement
- [ ] No behavior changes — docs only
