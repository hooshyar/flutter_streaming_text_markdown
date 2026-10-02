---
id: TASK-022
title: 'Coverage in CI + README badge; raise lib line coverage to >=85%'
status: To Do
priority: low
labels:
  - improvement-plan-2026-09
  - tests
  - ci
created_date: '2026-09-24'
---

## Description

Baseline 2026-09-24: 70.2% lib line coverage (950/1353). Gaps: default_stream_provider 0%, streaming_shimmer 0%, animation_presets 3%, stream_provider 14%, theme 35%, controller 60%. The tracked coverage/lcov.info is stale (2026-08-25); untrack it or regenerate it in CI. streaming_text.dart (2,264 lines) is where recent bugs came from. See plan P1-5.

## Acceptance Criteria
- [ ] CI runs `flutter test --coverage` and publishes lcov (Codecov or generated shields badge)
- [ ] README coverage badge
- [ ] New tests raise lib/ line coverage to >=85%, prioritizing uncovered branches in streaming_text.dart
