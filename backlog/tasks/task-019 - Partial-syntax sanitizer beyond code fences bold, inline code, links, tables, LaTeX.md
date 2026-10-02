---
id: TASK-019
title: 'Partial-syntax sanitizer beyond code fences (bold, inline code, links, tables, LaTeX)'
status: Done
priority: medium
labels:
  - improvement-plan-2026-09
  - streaming
  - rendering
created_date: '2026-09-24'
---

## Description

We only withhold an unbalanced ``` fence (`_stableRenderText`). Competitors (flutter_markdown_stream, streamdown) handle unclosed bold/italic/strike/inline code/links/tables/LaTeX mid-stream without raw-marker flashes. First check what gpt_markdown 1.3's plusparse already handles, then fill the gaps. See plan P1-2.

## Acceptance Criteria
- [ ] Table-driven test matrix of mid-stream prefixes (`**bol`, `*ita`, backtick code, `[link](htt`, partial table header/row, `$x^`, `~~st`, nested list, `##`): no exception, no raw-marker flash-then-shrink, visible length monotonic
- [ ] Logic in a pure-Dart helper with unit tests
- [ ] Final render after stream completion is byte-identical to the current behavior

## Final Summary

Mid-stream sanitizer is the pure-Dart `lib/src/render/mend.dart` with `test/markdown/mend_test.dart` and widget tests (1.11.0).
