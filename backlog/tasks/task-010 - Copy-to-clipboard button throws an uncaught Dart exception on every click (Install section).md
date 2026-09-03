---
id: TASK-010
title: 'Copy-to-clipboard button throws an uncaught Dart exception on every click (Install section)'
status: Done
priority: high
labels:
  - web-demo
  - qa-2026-09-03
created_date: '2026-09-03'
---

## Description

Found by the 2026-09-03 visual QA pass of the live demo https://hooshyar.github.io/flutter_streaming_text_markdown/ (v1.10.0). Fix in the package/example, add a regression test, redeploy the demo, and verify live.

Repro: scroll to Install, click the copy icon next to the pub add command. The "Copied to clipboard" toast shows, but the browser console logs an uncaught exception each time: Uncaught {dartException: Eh, ...} at main.dart.js, preceded by "[debug] Injecting <script> tag. Using callback." Reproduced twice. Likely the clipboard/url_launcher web interop path; fix so no exception is thrown on web, keep the toast.
