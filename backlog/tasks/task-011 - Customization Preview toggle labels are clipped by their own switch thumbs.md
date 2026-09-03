---
id: TASK-011
title: 'Customization Preview toggle labels are clipped by their own switch thumbs'
status: To Do
priority: high
labels:
  - web-demo
  - qa-2026-09-03
created_date: '2026-09-03'
---

## Description

Found by the 2026-09-03 visual QA pass of the live demo https://hooshyar.github.io/flutter_streaming_text_markdown/ (v1.10.0). Fix in the package/example, add a regression test, redeploy the demo, and verify live.

Repro: scroll to Customization Preview, look at the row of toggles under the Fade-in curve dropdown. Every label loses its first 1-3 characters behind the switch (wordByWord -> "ordByWord", fadeIn -> "adeIn", markdown -> "arkdown", latex -> "tex", animations -> "nctions"). Reproduced at 800px and after resizing, so it is the Row spacing, not just a breakpoint. Fix the layout (wrap/spacing) and add a golden.
