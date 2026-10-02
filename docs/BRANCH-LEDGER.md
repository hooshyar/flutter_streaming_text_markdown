# Branch ledger (flutter_streaming_text_markdown)

Written 2026-10-02 during the fleet consolidation (Hooshyar: merge all work to main, lose nothing).

## State of main
- 1.11.0 is published and tagged (`v1.11.0`): RevealEngine core, `gpt_markdown` 1.3, markdown fade redesign, `CodeBlockView`/`CodeBlockTheme`, controller accessors, accessibility. Everything from PR #18 (`agent/stm-_integration`), PR #19 (improvement plan) and PR #20 (consolidation chores) is on `main`.
- The ~21 `agent/stm/*` slice branches and worktrees were pruned earlier today (all were on origin or merged); `agent/stm-_integration` was deleted after the merge.
- B2 default-typography layer (B2-S2) was built and then reverted on purpose (descope, commit `059a256`). It stays in git history; nothing else is parked.

## Archive tags (kept, never deleted)
| Tag | What it holds | Decision |
|---|---|---|
| `archive/2026-10-02/claude/flutter-package-audit-530uly` | June 2026 audit branch (v1.10.0 fixes, AUDIT.md, stream+controller completion fix) | DROP: v1.10.0 and v1.10.1 shipped from this work; the audit is superseded by 1.11.0 |
| `archive/2026-10-02/backup/wip-2026-10-02/dev-team_wt_flutter_streaming_text_markdown_stm-_integration` | uncommitted release-prep edits (changelog, pubspec, exports test) | DROP: the final versions landed in `2bdb293` and `da75ed9` |
| `archive/2026-10-02/backup/wip-2026-10-02/dev-team_wt_flutter_streaming_text_markdown_stm-b1s3` | one `analysis_options.yaml` churn line | DROP: SDK auto-edit, the B2 plan says revert it |

## Backlog after this pass
- Done: task-015 to 021 (all shipped in 1.11.0, statuses reconciled). task-013 and task-022 filenames renamed (Windows-invalid characters) and a `portable-filenames` CI job added.
- task-022 (coverage in CI, README badge): see its Final Summary for the measured baseline and what was added.
- task-023 (cross-link DotLoader in the example and README, optional): open, depends on flutter_dot_loader 1.1.0 being published.
- Left in `~/.dev-team/wt/flutter_streaming_text_markdown/PHASE-B2-LEAN.md`: the B2 lean plan, kept as a historical note outside the repo.
