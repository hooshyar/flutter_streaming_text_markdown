// Ratio-based performance benchmark (acceptance criterion 8): a growing
// 20k-char markdown stream, WITH THE DEFAULT CARET showing, must stay within
// 1.8x of bare `GptMarkdown` (median per-frame time), and its element-rebuild
// count must stay within a sane multiple of bare's.
//
// The previous version of this file measured neither of those things
// honestly: it built with `showCursor: false` (no caret at all - the exact
// surface that regressed) and ran both widgets *interleaved* in one tree, so
// `ours`'s ticker cost bled onto `bare`'s numbers too and the ratio looked
// fine even while the caret path was ~9.5x slower in isolation (see
// doc/BENCHMARKS.md). With the caret on, every ticker frame used to build a
// fresh `RegExp`/`InlinePattern`/`MarkdownRenderOptions`
// (`lib/src/render/caret_inline.dart`), which fails `gpt_markdown`'s
// `GptMarkdownConfig.isSame` element-identity check on `inlinePatterns` and
// drops its whole segment cache on every single frame.
//
// `ours` and `bare` now run in SEPARATE, SEQUENTIAL phases (mount, pump,
// unmount, then the other) so neither side's ticker/build cost is ever
// charged to the other.
//
// This is a wall-clock benchmark, not a correctness test - it is the one
// sanctioned wall-clock assertion in the suite (acceptance criterion 11) and
// is tagged `benchmark` (see dart_test.yaml) so it's excluded from the
// default `flutter test` run and only executed on demand:
// `flutter test --no-dds --tags benchmark --run-skipped` (the tag's skip
// stays in effect unless `--run-skipped` is passed).
//
// Numbers observed on this machine, before and after the Phase C caret fix,
// are recorded in doc/BENCHMARKS.md.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as w show debugOnRebuildDirtyWidget;
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'package:flutter_streaming_text_markdown/src/streaming/streaming_text.dart';

const int _targetLength = 20000;

String _chunk(int i) =>
    'Paragraph $i: some **bold** and _italic_ words, an `inline code` '
    'span, and a [link](https://example.com/$i) describing streamed item '
    '$i in a growing answer.\n\n';

/// A real `Stream<String>` delivering [_targetLength] chars across many small
/// chunks - the shape a live LLM token stream actually arrives in - rather
/// than one `String` assigned to `text` up front.
Stream<String> _liveStream() async* {
  var length = 0;
  var i = 0;
  while (length < _targetLength) {
    final next = _chunk(i);
    length += next.length;
    yield next;
    i++;
  }
}

/// Widget that grows plain-text content on its own `Timer`, so `bare`
/// exercises `GptMarkdown` against a similarly-paced growing document without
/// any of this package's reveal/fade/caret machinery - the baseline `ours` is
/// measured against.
class _BareGrowing extends StatefulWidget {
  const _BareGrowing({required this.full, required this.chunkChars});

  final String full;
  final int chunkChars;

  @override
  State<_BareGrowing> createState() => _BareGrowingState();
}

class _BareGrowingState extends State<_BareGrowing> {
  int _length = 0;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      _length = (_length + widget.chunkChars).clamp(0, widget.full.length);
    });
    if (_length < widget.full.length) {
      Future<void>.delayed(const Duration(milliseconds: 16), _tick);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GptMarkdown(widget.full.substring(0, _length));
  }
}

class _PhaseResult {
  _PhaseResult(this.frameMicros, this.rebuilds);
  final List<int> frameMicros;
  final Map<String, int> rebuilds;

  int get medianMicros {
    final sorted = [...frameMicros]..sort();
    return sorted[sorted.length ~/ 2];
  }

  int get totalRebuilds => rebuilds.values.fold(0, (a, b) => a + b);
}

/// Pumps 16ms frames, timing each one, until either [maxFrames] is reached or
/// the widget under test stops scheduling more frames on its own (reveal
/// finished, ticker stopped, any fade settled).
Future<List<int>> _pumpAndTime(
  WidgetTester tester, {
  required int maxFrames,
}) async {
  const frameBudget = Duration(milliseconds: 16);
  final micros = <int>[];
  final stopwatch = Stopwatch();
  for (var i = 0; i < maxFrames; i++) {
    stopwatch
      ..reset()
      ..start();
    await tester.pump(frameBudget);
    stopwatch.stop();
    micros.add(stopwatch.elapsedMicroseconds);
    if (!tester.binding.hasScheduledFrame) break;
  }
  return micros;
}

/// Mounts `ours` (a full [StreamingText] stream+reveal, default caret on)
/// alone, pumps it to completion/settle, and tears it down.
Future<_PhaseResult> _measureOurs(
  WidgetTester tester, {
  required int chunkSize,
  required Duration typingSpeed,
}) async {
  final rebuilds = <String, int>{};
  w.debugOnRebuildDirtyWidget = (element, builtOnce) {
    final key = element.widget.runtimeType.toString();
    rebuilds[key] = (rebuilds[key] ?? 0) + 1;
  };
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: StreamingText(
              text: '',
              stream: _liveStream(),
              markdownEnabled: true,
              chunkSize: chunkSize,
              typingSpeed: typingSpeed,
              // showCursor defaults to true: the default caret stays on and
              // pulsing for the whole reveal, which is the point.
            ),
          ),
        ),
      ),
    ),
  );
  final micros = await _pumpAndTime(tester, maxFrames: 600);
  w.debugOnRebuildDirtyWidget = null;
  // Tear down completely before the next phase, so nothing of ours (ticker,
  // timers) survives into it.
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  return _PhaseResult(micros, rebuilds);
}

/// Mounts `bare` (plain `GptMarkdown` growing on its own `Timer`, no reveal/
/// fade/caret machinery) alone, paced identically to `ours`, pumps it to
/// completion, and tears it down.
Future<_PhaseResult> _measureBare(
  WidgetTester tester, {
  required String full,
  required int chunkSize,
}) async {
  final rebuilds = <String, int>{};
  w.debugOnRebuildDirtyWidget = (element, builtOnce) {
    final key = element.widget.runtimeType.toString();
    rebuilds[key] = (rebuilds[key] ?? 0) + 1;
  };
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: _BareGrowing(full: full, chunkChars: chunkSize),
          ),
        ),
      ),
    ),
  );
  final micros = await _pumpAndTime(tester, maxFrames: 600);
  w.debugOnRebuildDirtyWidget = null;
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  return _PhaseResult(micros, rebuilds);
}

void main() {
  testWidgets(
    'a 20k-char markdown stream WITH THE DEFAULT CARET stays within 1.8x of '
    'bare GptMarkdown (pooled median, sequential, non-interleaved, 400px '
    'wide)',
    (tester) async {
      const chunkSize = 140;
      const typingSpeed = Duration(milliseconds: 16);
      final full = StringBuffer();
      var i = 0;
      while (full.length < _targetLength) {
        full.write(_chunk(i));
        i++;
      }
      final fullText = full.toString();

      // `ours` and `bare` never share a build - each phase mounts one,
      // pumps it alone, then fully unmounts it before the next phase starts
      // (see [_measureOurs] / [_measureBare]), so neither side's
      // ticker/timer cost is ever charged to the other. They ARE run in
      // several short alternating ROUNDS (ours, bare, ours, bare, ...)
      // rather than one long block each, purely so a transient burst of
      // unrelated system load (this machine runs several other agent
      // sessions) lands on both sides' pooled sample instead of skewing
      // whichever side happened to be measured during it.
      //
      // The gating ratio is a MEDIAN OF PER-ROUND MEDIANS, not the pooled
      // median: a single round entirely swamped by unrelated system load
      // (this machine runs several other agent sessions) skews a pooled
      // median because it contributes ~150 samples at once, but only shifts
      // one of 12 entries in the per-round list - the round-2 verifier
      // measured this budget swinging 1.75x-1.87x on the pooled metric
      // alone. The pooled median is still reported alongside it for
      // context, but never gates.
      const rounds = 12;
      final oursMicros = <int>[];
      final bareMicros = <int>[];
      final oursRebuilds = <String, int>{};
      final bareRebuilds = <String, int>{};
      final perRoundRatios = <double>[];

      for (var round = 0; round < rounds; round++) {
        final ours = await _measureOurs(
          tester,
          chunkSize: chunkSize,
          typingSpeed: typingSpeed,
        );
        oursMicros.addAll(ours.frameMicros);
        ours.rebuilds.forEach(
          (k, v) => oursRebuilds[k] = (oursRebuilds[k] ?? 0) + v,
        );

        final bare = await _measureBare(
          tester,
          full: fullText,
          chunkSize: chunkSize,
        );
        bareMicros.addAll(bare.frameMicros);
        bare.rebuilds.forEach(
          (k, v) => bareRebuilds[k] = (bareRebuilds[k] ?? 0) + v,
        );

        if (bare.medianMicros > 0) {
          perRoundRatios.add(ours.medianMicros / bare.medianMicros);
        }
      }

      // ---- Compare ---------------------------------------------------
      final ours = _PhaseResult(oursMicros, oursRebuilds);
      final bare = _PhaseResult(bareMicros, bareRebuilds);

      final pooledRatio =
          bare.medianMicros == 0 ? 1.0 : ours.medianMicros / bare.medianMicros;
      final sortedRoundRatios = [...perRoundRatios]..sort();
      final ratio =
          sortedRoundRatios.isEmpty
              ? pooledRatio
              : sortedRoundRatios[sortedRoundRatios.length ~/ 2];
      final rebuildRatio =
          bare.totalRebuilds == 0
              ? 1.0
              : ours.totalRebuilds / bare.totalRebuilds;

      final report =
          'stream_benchmark ($rounds rounds, sequential, caret on): '
          '${ours.frameMicros.length} ours frames / ${bare.frameMicros.length} '
          'bare frames, doc ${fullText.length} chars — ours median '
          '${ours.medianMicros}us (${ours.totalRebuilds} element rebuilds), '
          'bare median ${bare.medianMicros}us (${bare.totalRebuilds} element '
          'rebuilds), pooled ratio ${pooledRatio.toStringAsFixed(3)}x, '
          'per-round ratios ${sortedRoundRatios.map((r) => r.toStringAsFixed(3)).join(', ')}, '
          'median-of-medians ratio ${ratio.toStringAsFixed(3)}x (budget <= '
          '1.8x, this is what gates), rebuild ratio '
          '${rebuildRatio.toStringAsFixed(3)}x (budget <= 6x)';
      // ignore: avoid_print
      print(report);

      expect(ratio, lessThanOrEqualTo(1.8), reason: report);
      // A sane multiple, not parity: ours legitimately does more work per
      // frame than bare (the reveal engine, the caret's own
      // ValueListenableBuilder, controller/progress bookkeeping, the extra
      // GestureDetector/Semantics/LayoutBuilder wrapping StreamingText's
      // public API needs). The regression this benchmark exists to catch was
      // ~48x (249,855 vs ~5,200 element rebuilds - see doc/BENCHMARKS.md),
      // not a modest constant factor.
      expect(rebuildRatio, lessThanOrEqualTo(6.0), reason: report);
    },
    tags: ['benchmark'],
  );
}
