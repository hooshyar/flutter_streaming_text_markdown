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

There is no tracked coverage baseline (see plan section 1.1 for the 2026-09-24 numbers). streaming_text.dart (2,264 lines) is where recent bugs came from. See plan P1-5.

## Acceptance Criteria
- [ ] CI runs `flutter test --coverage` and publishes lcov (Codecov or generated shields badge)
- [ ] README coverage badge
- [ ] New tests raise lib/ line coverage to >=85%, prioritizing uncovered branches in streaming_text.dart
