---
id: TASK-015
title: 'Restore 160/160 pub points: migrate off gpt_markdown 1.3.0 deprecations'
status: To Do
priority: high
labels:
  - improvement-plan-2026-09
  - pub-score
  - deps
created_date: '2026-09-24'
---

## Description

pub.dev re-analysed with gpt_markdown 1.3.0 (released 2026-09-20) and dropped us to 150/160 (Pass static analysis 40/50). The cause is 4 deprecation INFOs in lib/src/streaming/streaming_text.dart `_buildSimpleMarkdown` (~L2140-2161): `sourceTagBuilder` -> `inlineSourceTagBuilder`, `linkBuilder` -> `inlineLinkBuilder`, `components` -> `blockComponents`, `inlineComponents` -> `inlinePatterns`/`inlineDirectives`. Passing `components`/`inlineComponents` at all also forces gpt_markdown's legacy regex parser (no segment cache/lazy rendering) per its MIGRATION.md. See docs/IMPROVEMENT-PLAN-2026-09.md P0-1. Same class of bug as TASK-001.

## Acceptance Criteria
- [ ] `gpt_markdown: ^1.3.0`; `environment` sdk/flutter floor matches what gpt_markdown actually requires (Dart >=3.7, Flutter >=3.32)
- [ ] lib uses none of the deprecated gpt_markdown args; existing public `sourceTagBuilder`/`linkBuilder`/`highlightBuilder` keep working via span adapters (`baselineWidgetSpan`), each covered by a widget test
- [ ] New pass-throughs `blockComponents`, `inlinePatterns`, `inlineDirectives` on StreamingTextMarkdown/StreamingText/presets; our `components`/`inlineComponents` marked @Deprecated pointing at them
- [ ] `flutter pub upgrade && flutter analyze` clean; `flutter pub downgrade && flutter analyze` clean; `pana .` = 160/160
- [ ] `flutter test` all green; CHANGELOG entry; release 1.11.0 by tag; pub.dev shows 160/160
