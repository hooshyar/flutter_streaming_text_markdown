---
id: TASK-012
title: 'LaTeX feature card does not typeset math — quadratic formula renders as fused plain text'
status: Done
priority: high
labels:
  - web-demo
  - qa-2026-09-03
created_date: '2026-09-03'
---

## Description

Found by the 2026-09-03 visual QA pass of the live demo https://hooshyar.github.io/flutter_streaming_text_markdown/ (v1.10.0). Fix in the package/example, add a regression test, redeploy the demo, and verify live.

Repro: Features -> LaTeX card (badge latexEnabled: true). The quadratic formula renders roughly as "x = -b ± √b^2  4ac2a": no fraction bar, no superscripts, no separator between 4ac and 2a, so the formula reads as wrong. Eulers identity and the integral also show ^ literally. Decide honestly: either the package renders real LaTeX (wire flutter_math_fork or equivalent behind latexEnabled and prove it with a golden) or the card/README must stop claiming LaTeX and describe what is actually done (Unicode symbol substitution). Misleading feature claims cost pub.dev credibility.
