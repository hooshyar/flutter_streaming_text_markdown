---
id: TASK-017
title: 'Long-stream perf benchmark vs bare GptMarkdown 1.3 (12KB / 50KB)'
status: To Do
priority: medium
labels:
  - improvement-plan-2026-09
  - perf
created_date: '2026-09-24'
---

## Description

We rebuild the full GptMarkdown tree on every typing tick. gpt_markdown 1.3 claims 31x faster per-chunk streaming via segment cache (74x with SliverGptMarkdown). Measure whether we actually get that after TASK-015. See plan P1-4.

## Acceptance Criteria
- [ ] Benchmark (test or integration_test traceAction) records avg + p90 frame build time at 12KB and 50KB for our widget vs bare GptMarkdown on the same stream
- [ ] Results written to docs/ and summarized in README
- [ ] Any >2x overhead vs bare GptMarkdown gets a follow-up fix task filed; evaluate an opt-in sliver/lazy mode for very long docs
