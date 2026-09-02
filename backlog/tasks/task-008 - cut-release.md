**Priority:** P1
**Component:** release
**Origin:** award-quality goal, 2026-09-02

**Problem:** Once the above fixes land, cut a release so users get them via pub.dev.

**Acceptance criteria:**
- [ ] Version bumped in pubspec.yaml (semver — patch/minor depending on changes; issue #17 fix is additive/backward-compatible so minor is fine)
- [ ] CHANGELOG.md updated with all changes since v1.9.1
- [ ] Tag pushed (`vX.Y.Z`) so CI publishes via pub.dev OIDC
- [ ] After CI completes, verify the pub.dev package page shows the new version and score
- [ ] conductor-notify sent with DONE summary

**Notes:** Publishing our own package is pre-authorized (not a "production deploy" gate) per the standing goal instructions. This is autonomous.
