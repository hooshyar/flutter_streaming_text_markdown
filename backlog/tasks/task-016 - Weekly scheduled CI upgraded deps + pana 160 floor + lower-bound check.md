---
id: TASK-016
title: 'Weekly scheduled CI: upgraded deps + pana 160 floor + lower-bound check'
status: To Do
priority: high
labels:
  - improvement-plan-2026-09
  - ci
  - pub-score
created_date: '2026-09-24'
---

## Description

No CI runs between our pushes, so upstream releases (gpt_markdown 1.2.0 and 1.3.0) silently cost 10 pub points twice. Add a scheduled job. See plan P0-2.

## Acceptance Criteria
- [ ] Workflow with `schedule:` (weekly cron) + `workflow_dispatch`
- [ ] Runs `flutter pub upgrade` then analyze + test
- [ ] Runs `pana --json --no-warning .` and fails if grantedPoints < 160
- [ ] Runs `flutter pub downgrade && flutter analyze` (lower-bound compatibility)
- [ ] Verified by a manual `gh workflow run` that passes after TASK-015 lands (and fails before it)
