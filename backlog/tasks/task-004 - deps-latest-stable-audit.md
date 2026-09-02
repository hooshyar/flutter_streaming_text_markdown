**Priority:** P2
**Component:** deps
**Origin:** award-quality goal, 2026-09-02

**Problem:** Dependencies and SDK constraints must track latest STABLE, verified via
`flutter pub outdated` (never from memory/training data).

**Acceptance criteria:**
- [ ] `flutter pub outdated` run in repo root and in `example/`
- [ ] Every outdated dependency (incl. `gpt_markdown`, dev deps) bumped to latest stable compatible version
- [ ] SDK constraint (`environment: sdk:` in pubspec.yaml) checked against current stable Dart/Flutter
- [ ] `flutter analyze` + `flutter test` pass after bumps
- [ ] Any dependency deliberately held back is noted with why
