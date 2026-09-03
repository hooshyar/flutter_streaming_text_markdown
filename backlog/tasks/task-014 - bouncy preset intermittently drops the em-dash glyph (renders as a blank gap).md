---
id: TASK-014
title: 'bouncy preset intermittently drops the em-dash glyph (renders as a blank gap)'
status: Done
priority: low
labels:
  - web-demo
  - qa-2026-09-03
created_date: '2026-09-03'
---

## Description

Found by the 2026-09-03 visual QA pass of the live demo https://hooshyar.github.io/flutter_streaming_text_markdown/ (v1.10.0). Fix in the package/example, add a regression test, redeploy the demo, and verify live.

Repro: select the bouncy preset or replay it; on 2 of 3 attempts in light theme the em-dash in "flutter_streaming_text_markdown — a package for..." was missing, leaving a double-space gap, while every other character rendered. Likely a per-character bounce animation that does not settle to full opacity for that glyph. Verify on a real device/browser, fix, add a test that every character reaches opacity 1 at animation end.
