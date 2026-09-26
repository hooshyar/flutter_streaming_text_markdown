# Benchmarks

## Streaming markdown vs bare `GptMarkdown` (acceptance criterion 8)

`test/perf/stream_benchmark_test.dart` grows a 400px-wide markdown document
to ~20k characters in ~150-char chunks, applying each chunk to a
`StreamingText` widget and to a bare `GptMarkdown` widget mounted side by
side, **interleaved** frame by frame (`ours`, then `bare`, repeat), so JIT
warmup / GC pauses / scheduler jitter land on both sides roughly equally
instead of skewing whichever engine happens to run first or "cold". Each
widget only rebuilds on its own `setState`, so the measured duration for a
frame reflects that one engine's incremental update cost, not both.

The test is tagged `benchmark` in `dart_test.yaml` (skipped by default;
`flutter test --tags benchmark --run-skipped` to run it) since a wall-clock,
ratio-based assertion is inherently noisier than the rest of the suite —
this is the one sanctioned wall-clock assertion (acceptance criterion 11).

**Budget:** median ratio (ours / bare) ≤ 1.8x. **Target:** ~1.3x.

**Observed** (this machine, `flutter test --tags benchmark --run-skipped`,
127 interleaved frames, final document 20,117 chars, 3 consecutive runs):

| Run | ours median | bare median | ratio |
|---|---|---|---|
| 1 | 3697us | 3698us | 1.000x |
| 2 | 4438us | 4337us | 1.023x |
| 3 | 4146us | 4176us | 0.993x |

All three runs land at essentially **1.0x** — well inside both the 1.8x
budget and the ~1.3x target. This reflects the S1 migration onto
`gpt_markdown` 1.3's own incremental segment cache: `StreamingText` no
longer re-parses the whole buffer on every rebuild (the old
`_buildMarkdownBody` did), so its per-frame cost converges on
`GptMarkdown`'s own cost plus a thin, O(1) wrapper (`withholdOpenFence`,
style/theme resolution, the optional caret inline pattern).

Environment: Flutter 3.47.5 (stable), `gpt_markdown: ^1.3.0`, run on the
build machine's default `flutter test` VM (debug mode; release-mode numbers
would be lower for both sides but the *ratio* is what's asserted).
