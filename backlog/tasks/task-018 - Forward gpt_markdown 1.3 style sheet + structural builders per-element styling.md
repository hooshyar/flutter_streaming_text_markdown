---
id: TASK-018
title: 'Forward gpt_markdown 1.3 style sheet + structural builders (per-element styling)'
status: To Do
priority: high
labels:
  - improvement-plan-2026-09
  - api
  - styling
created_date: '2026-09-24'
---

## Description

The most frequent issue theme (#5, #10, #13, #17) is styling. gpt_markdown 1.3 exposes `styleSheet`, `inlineCodeStyle`, `headingBuilder`, `tableBuilder`, `blockQuoteBuilder`, `orderedListBuilder`/`unOrderedListBuilder`, `hrBuilder`, `checkboxBuilder`, `onCodeCopy`, `onImageTap`, `onSourceTagTap`. We forward none of them, and our #13 answer pointed users to the now-deprecated `components`. Depends on TASK-015. See plan P1-1.

## Acceptance Criteria
- [ ] Each param exposed on StreamingTextMarkdown, StreamingText and preset constructors, forwarded to GptMarkdown
- [ ] Required gpt_markdown types re-exported so users don't need a direct gpt_markdown import
- [ ] One widget test per builder/style proving it is applied
- [ ] README "Per-element styling" section with example; comment on issue #13 with the new API
