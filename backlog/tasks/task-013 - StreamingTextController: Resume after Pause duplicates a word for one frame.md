---
id: TASK-013
title: 'StreamingTextController: Resume after Pause duplicates a word for one frame'
status: Done
priority: medium
labels:
  - web-demo
  - qa-2026-09-03
created_date: '2026-09-03'
---

## Description

Found by the 2026-09-03 visual QA pass of the live demo https://hooshyar.github.io/flutter_streaming_text_markdown/ (v1.10.0). Fix in the package/example, add a regression test, redeploy the demo, and verify live.

Repro: Controller section -> Restart, let a few words stream, Pause, Resume; the text momentarily reads "...being animated animated with a StreamingTextController". Final state is correct (Skip shows no duplicate), so it is transient animation state on resume. Fix and add a widget test that pauses/resumes and asserts the visible text never contains a doubled token.
