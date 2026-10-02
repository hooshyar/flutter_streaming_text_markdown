---
id: TASK-021
title: 'Accessibility: reduced motion, semantics mid-stream, selectable on StreamingTextMarkdown'
status: Done
priority: medium
labels:
  - improvement-plan-2026-09
  - a11y
created_date: '2026-09-24'
---

## Description

There is no MediaQuery.disableAnimations handling, no semantics tests while streaming, and `selectable`/`semanticsLabel` exist on StreamingText but aren't exposed on StreamingTextMarkdown. gpt_markdown 1.3 already honors reduced motion and fixed announcement storms. See plan P1-3.

## Acceptance Criteria
- [ ] disableAnimations=true renders full text instantly (widget test)
- [ ] StreamingTextMarkdown (and presets) expose `selectable` and `semanticsLabel`
- [ ] Cursor/shimmer excluded from semantics; test shows no per-character semantics churn mid-stream
- [ ] textContrastGuideline / labeledTapTargetGuideline pass on the example home screen

## Final Summary

Reduced motion, single-announcement semantics, `selectable` and `semanticsLabel` shipped in 1.11.0 (`test/a11y/*`).
