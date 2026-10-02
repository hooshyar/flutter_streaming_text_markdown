---
id: TASK-023
title: 'Show flutter_dot_loader as the "waiting for first token" indicator in the example and README'
status: To Do
priority: low
labels:
  - docs
  - example
  - cross-promotion
created_date: '2026-10-02'
---

## Description

Cross-repo follow-up of flutter_dot_loader TASK-005 (dot_loader 1.1.0 adds an inline `DotLoader.thinking()`). Before the first token arrives a stream shows nothing; a small dot loader is the natural placeholder.

## Acceptance Criteria
- [ ] The example app shows `DotLoader.thinking()` (example-only dependency, never added to the package pubspec) until the first chunk of a demo stream arrives.
- [ ] README gets a 6-line "waiting for the first token" snippet that links `flutter_dot_loader`, clearly optional.
- [ ] pana stays 160/160 and the package gains no dependency.
