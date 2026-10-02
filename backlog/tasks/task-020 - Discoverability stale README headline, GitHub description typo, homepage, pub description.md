---
id: TASK-020
title: 'Discoverability: stale README headline, GitHub description typo, homepage, pub description'
status: Done
priority: medium
labels:
  - improvement-plan-2026-09
  - docs
  - discoverability
created_date: '2026-09-24'
---

## Description

README top section still says "New: v1.9.1" (current is 1.10.1). The GitHub repo description starts with "erfect for LLM Applications!" (typo). The homepage points to dilacode.com instead of the live demo. The pubspec description misses typewriter/ChatGPT/Claude/Gemini/AI chat search terms. See plan P0-3 / P1-6.

## Acceptance Criteria
- [ ] README "what's new" matches the current version (or points to CHANGELOG), plus a "When to use this vs gpt_markdown / flutter_markdown_plus" section
- [ ] `gh repo edit` fixes the description typo, sets homepage to https://hooshyar.github.io/flutter_streaming_text_markdown/, and adds topics (markdown, llm, streaming, chatgpt, flutter-package)
- [ ] pubspec description rewritten (60-180 chars) with the key search terms; pana still 160/160

## Final Summary

README now has a "When to use this package" section, the pubspec description was rewritten with the key search terms, and the GitHub description typo and homepage were fixed (2026-10-02).
