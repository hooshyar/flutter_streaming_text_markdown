---
id: TASK-022
title: 'Coverage in CI + README badge; raise lib line coverage to >=85%'
status: Done
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

## Final Summary

Measured 2026-10-02 on main: lib/ line coverage 94.93% (3144/3312), already above the 85% target, so no new tests were needed. CI now runs `flutter test --no-dds --coverage` (benchmark tag excluded), enforces a 90% floor with `tool/check_coverage.dart 90` and uploads `coverage/lcov.info` as an artifact; the README carries a static coverage badge (update it when the floor moves). A hosted badge service (Codecov) was not added because it needs a repo token from Hooshyar.
