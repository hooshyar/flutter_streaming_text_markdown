**Priority:** P2
**Component:** deps
**Origin:** award-quality goal, 2026-09-02

**Problem:** Dependencies and SDK constraints must track latest STABLE, verified via
`flutter pub outdated` (never from memory/training data).

**Acceptance criteria:**
- [x] `flutter pub outdated` run in repo root and in `example/`
- [x] Every outdated dependency (incl. `gpt_markdown`, dev deps) bumped to latest stable compatible version
- [x] SDK constraint (`environment: sdk:` in pubspec.yaml) checked against current stable Dart/Flutter
- [x] `flutter analyze` + `flutter test` pass after bumps
- [x] Any dependency deliberately held back is noted with why

**DONE 2026-09-03.** `flutter pub outdated` in both repo root and `example/`:
all direct + dev dependencies already at latest ("all up-to-date"). The only
outdated packages listed are transitive deps (`meta`, `vector_math`,
`material_color_utilities`, `clock`, `matcher`, `stack_trace`, `test_api`,
`url_launcher_android`) whose versions are pinned by the installed Flutter
SDK (3.41.6 stable) itself, not by this package's pubspec — nothing to bump
here. `gpt_markdown` constraint was already bumped to `^1.2.0` in task-001.
Did NOT run `flutter upgrade` (machine-wide Flutter SDK change, out of scope
for a package-level dependency audit and affects every other project on the
machine). pana's own "Package supports latest stable Dart and Flutter SDKs"
check already scores 10/10.
