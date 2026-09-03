---
id: TASK-009
title: 'Web demo header shows a hardcoded stale version badge (v1.9.1 while 1.10.0 is live)'
status: Done
priority: medium
labels:
  - example
  - web-demo
  - quick-fix
created_date: '2026-09-03'
---

## Description

Verified on the live web demo https://hooshyar.github.io/flutter_streaming_text_markdown/ on 2026-09-03
(deployed 04:43 UTC, after the v1.10.0 release): the badge next to pub.dev/GitHub reads **v1.9.1**.
The example hardcodes the version string, so every release leaves the demo lying about itself.

## Acceptance Criteria
- [ ] The badge is derived from `pubspec.yaml` (build-time `--dart-define` set by `pages.yml`, or a
      generated `version.dart`), never a literal.
- [ ] `pages.yml` supplies it on deploy; a test asserts badge == pubspec version.
- [ ] Redeploy; the live demo shows 1.10.0.
