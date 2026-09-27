// Delegation-spike benchmark (acceptance criterion 11 / B1-S4).
//
// Measures four arms on the same 20k-char growing markdown document, 400px
// wide, 16ms frames, and applies the decision rule fixed in advance by
// PHASE-B1-PLAN.md's "Decision: keep our engine and delegate only the
// per-word paint" section:
//
//   RULE: adopt the hybrid if the markdown stream is <=1.8x bare, final ==
//   source, and no timer is still pending 400ms after `isStreaming` goes
//   false. Otherwise markdown smoothFade becomes word-paced with no alpha,
//   and plain text keeps our fade_span.
//
// The four arms:
//   (A) ours today       - StreamingText driving GptMarkdown with no reveal
//                           delegation at all (the existing engine).
//   (B) the hybrid        - OUR code still grows the revealed `data` string
//                           (mirroring our engine's cursor); GptMarkdown is
//                           only asked to paint that already-revealed head
//                           with `animation: GptMarkdownAnimation.fade`,
//                           `revealFadeSeconds: 0.18` and a huge
//                           `charactersPerSecond` so its own pacing never
//                           lags our cursor - it just fades whatever we
//                           handed it.
//   (C) full delegation    - GptMarkdown owns EVERYTHING: it is mounted once
//                           with the whole final text and `isStreaming:
//                           true`, and reveals it on its own
//                           `charactersPerSecond` clock (left at gpt_markdown's
//                           own default, 300 - the literal "hand it over and
//                           let it drive" integration, and the pacing this
//                           decision's rejection list says "differs from the
//                           chat UI's").
//   (D) bare               - plain `GptMarkdown`, growing on its own `Timer`,
//                           no reveal/fade/caret machinery at all - the
//                           baseline every ratio is measured against.
//
// This file is intentionally self-contained (does not import the private
// helpers in test/perf/stream_benchmark_test.dart, which are file-private) -
// it reuses that file's alternating-rounds, sequential-mount/pump/unmount
// TECHNIQUE, not its code.
//
// Tagged `benchmark` (see dart_test.yaml): skipped by default, run with
// `flutter test --no-dds --tags benchmark --run-skipped
// test/perf/delegation_benchmark_test.dart`.

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

String _buildDoc() {
  final full = StringBuffer();
  var i = 0;
  while (full.length < _targetLength) {
    full.write(_chunk(i));
    i++;
  }
  return full.toString();
}

Stream<String> _liveStream(String full, int chunkSize) async* {
  var offset = 0;
  while (offset < full.length) {
    final end = (offset + chunkSize).clamp(0, full.length);
    yield full.substring(offset, end);
    offset = end;
  }
}

class _PhaseResult {
  _PhaseResult(this.frameMicros, this.rebuilds);
  final List<int> frameMicros;
  final Map<String, int> rebuilds;

  int get medianMicros {
    if (frameMicros.isEmpty) return 0;
    final sorted = [...frameMicros]..sort();
    return sorted[sorted.length ~/ 2];
  }

  int get totalRebuilds => rebuilds.values.fold(0, (a, b) => a + b);
}

/// Pumps 16ms frames, timing each one, until [maxFrames] is reached or the
/// widget under test stops scheduling more frames on its own.
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

Future<_PhaseResult> _measure(
  WidgetTester tester, {
  required Widget Function() build,
  required int maxFrames,
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
          child: SizedBox(width: 400, child: build()),
        ),
      ),
    ),
  );
  final micros = await _pumpAndTime(tester, maxFrames: maxFrames);
  w.debugOnRebuildDirtyWidget = null;
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  return _PhaseResult(micros, rebuilds);
}

/// (D) bare: plain `GptMarkdown`, growing on its own `Timer`, no reveal/fade/
/// caret machinery.
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

/// (B) the hybrid: OUR code grows `data`; `GptMarkdown` only paints the
/// already-revealed head with a fast fade.
class _HybridGrowing extends StatefulWidget {
  const _HybridGrowing({
    required this.full,
    required this.chunkChars,
    this.onDone,
  });
  final String full;
  final int chunkChars;
  final VoidCallback? onDone;

  @override
  State<_HybridGrowing> createState() => _HybridGrowingState();
}

class _HybridGrowingState extends State<_HybridGrowing> {
  int _length = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      _length = (_length + widget.chunkChars).clamp(0, widget.full.length);
      _done = _length >= widget.full.length;
    });
    if (_done) {
      widget.onDone?.call();
    } else {
      Future<void>.delayed(const Duration(milliseconds: 16), _tick);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GptMarkdown(
      widget.full.substring(0, _length),
      animation: GptMarkdownAnimation.fade,
      revealFadeSeconds: 0.18,
      // Huge on purpose: our own engine already decided what is revealed
      // (widget.full.substring(0, _length)) - GptMarkdown's head must never
      // lag behind that cursor, it only softens the paint.
      charactersPerSecond: 1000000,
      isStreaming: !_done,
    );
  }
}

/// (C) full delegation: `GptMarkdown` owns pacing AND paint. Mounted once
/// with the whole final text and `isStreaming: true`; it reveals on its own
/// clock (default `charactersPerSecond`, 300) rather than ours.
class _FullDelegation extends StatelessWidget {
  const _FullDelegation({required this.full});
  final String full;

  @override
  Widget build(BuildContext context) {
    return GptMarkdown(
      full,
      animation: GptMarkdownAnimation.fade,
      revealFadeSeconds: 0.18,
      isStreaming: true,
      // Deliberately left at gpt_markdown's own default (300 chars/s): full
      // delegation means NOT retuning its pacing to match our chat UI.
    );
  }
}

/// Recursively collects every explicit-color alpha found in the current
/// RichText tree - used to prove the hybrid's fade is real (not skipped).
List<double> _spanAlphas(WidgetTester tester) {
  final alphas = <double>[];
  void visit(InlineSpan span) {
    if (span is TextSpan) {
      final color = span.style?.color;
      if (color != null) alphas.add(color.a);
      span.children?.forEach(visit);
    }
  }

  for (final richText in _richTextWidgets(tester)) {
    visit(richText.text);
  }
  return alphas;
}

/// `gpt_markdown` renders through `BidiRichText` (a `RichText` subclass, see
/// `custom_widgets/bidi_rich_text.dart`), not `RichText` itself -
/// `find.byType(RichText)` matches on exact runtime type and misses it, so
/// this walks the tree with a predicate instead.
List<RichText> _richTextWidgets(WidgetTester tester) =>
    tester
        .widgetList(find.byWidgetPredicate((w) => w is RichText))
        .cast<RichText>()
        .toList();

void main() {
  const chunkSize = 140;
  const maxFrames = 600;

  testWidgets('delegation spike: ours vs hybrid vs full-delegation vs bare '
      '(20k-char markdown, 400px, 16ms frames)', (tester) async {
    final full = _buildDoc();

    final results = <String, _PhaseResult>{};
    final oursRebuilds = <String, int>{};
    final hybridRebuilds = <String, int>{};
    final fullRebuilds = <String, int>{};
    final bareRebuilds = <String, int>{};
    final defaultAfterS5Rebuilds = <String, int>{};
    final oursMicros = <int>[];
    final hybridMicros = <int>[];
    final fullMicros = <int>[];
    final bareMicros = <int>[];
    final defaultAfterS5Micros = <int>[];

    const rounds = 6;
    for (var round = 0; round < rounds; round++) {
      final ours = await _measure(
        tester,
        maxFrames: maxFrames,
        build:
            () => StreamingText(
              // Pinned to the pre-S5 legacy reveal (this arm is "ours
              // today", the baseline S4 measured) - the new default is
              // measured separately below as E_defaultAfterS5.
              revealMode: null,
              text: '',
              stream: _liveStream(full, chunkSize),
              markdownEnabled: true,
              chunkSize: chunkSize,
              typingSpeed: const Duration(milliseconds: 16),
            ),
      );
      oursMicros.addAll(ours.frameMicros);
      ours.rebuilds.forEach(
        (k, v) => oursRebuilds[k] = (oursRebuilds[k] ?? 0) + v,
      );

      final defaultAfterS5 = await _measure(
        tester,
        maxFrames: maxFrames,
        build:
            () => StreamingText(
              // No `revealMode`/`pacing` override: the actual shipped
              // 2.0 default (`RevealMode.smoothFade`, catch-up pacing
              // for streams) - see acceptance criterion 11's "the
              // DEFAULT StreamingTextMarkdown on a stream must be <=1.8x
              // bare in BOTH benchmarks".
              text: '',
              stream: _liveStream(full, chunkSize),
              markdownEnabled: true,
              chunkSize: chunkSize,
              typingSpeed: const Duration(milliseconds: 16),
            ),
      );
      defaultAfterS5Micros.addAll(defaultAfterS5.frameMicros);
      defaultAfterS5.rebuilds.forEach(
        (k, v) =>
            defaultAfterS5Rebuilds[k] = (defaultAfterS5Rebuilds[k] ?? 0) + v,
      );

      final hybrid = await _measure(
        tester,
        maxFrames: maxFrames,
        build: () => _HybridGrowing(full: full, chunkChars: chunkSize),
      );
      hybridMicros.addAll(hybrid.frameMicros);
      hybrid.rebuilds.forEach(
        (k, v) => hybridRebuilds[k] = (hybridRebuilds[k] ?? 0) + v,
      );

      final fullDelegation = await _measure(
        tester,
        maxFrames: maxFrames,
        build: () => _FullDelegation(full: full),
      );
      fullMicros.addAll(fullDelegation.frameMicros);
      fullDelegation.rebuilds.forEach(
        (k, v) => fullRebuilds[k] = (fullRebuilds[k] ?? 0) + v,
      );

      final bare = await _measure(
        tester,
        maxFrames: maxFrames,
        build: () => _BareGrowing(full: full, chunkChars: chunkSize),
      );
      bareMicros.addAll(bare.frameMicros);
      bare.rebuilds.forEach(
        (k, v) => bareRebuilds[k] = (bareRebuilds[k] ?? 0) + v,
      );
    }

    results['A_ours'] = _PhaseResult(oursMicros, oursRebuilds);
    results['B_hybrid'] = _PhaseResult(hybridMicros, hybridRebuilds);
    results['C_full'] = _PhaseResult(fullMicros, fullRebuilds);
    results['D_bare'] = _PhaseResult(bareMicros, bareRebuilds);
    results['E_defaultAfterS5'] = _PhaseResult(
      defaultAfterS5Micros,
      defaultAfterS5Rebuilds,
    );

    final bareMedian = results['D_bare']!.medianMicros;
    double ratioOf(String key) =>
        bareMedian == 0 ? 1.0 : results[key]!.medianMicros / bareMedian;

    final ratioA = ratioOf('A_ours');
    final ratioB = ratioOf('B_hybrid');
    final ratioC = ratioOf('C_full');
    final ratioE = ratioOf('E_defaultAfterS5');

    // ---- Correctness checks on B (hybrid), per the decision rule -----
    // 1) final text == source, once the hybrid's own growth completes and
    //    GptMarkdown finishes revealing the tail it was handed.
    var hybridDone = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: _HybridGrowing(
                full: full,
                chunkChars: chunkSize,
                onDone: () => hybridDone = true,
              ),
            ),
          ),
        ),
      ),
    );
    // Drive growth to completion, then let the fast fade (charactersPerSecond
    // huge, revealFadeSeconds 0.18) finish settling.
    var guard = 0;
    while (!hybridDone && guard < 5000) {
      await tester.pump(const Duration(milliseconds: 16));
      guard++;
    }
    await tester.pump(const Duration(milliseconds: 250));

    final renderedTexts =
        _richTextWidgets(tester).map((r) => r.text.toPlainText()).join();
    // A settled, unanimated `GptMarkdown(full)` is the reference: markdown
    // rendering itself drops non-content markup that is never meant to
    // print (a `[link](url)`'s url, a `**`/`_`/`` ` `` delimiter) - that is
    // correct for every arm, not data loss. What "final == source" needs to
    // prove for the hybrid specifically is that its fade layer did not
    // hold back, drop or duplicate anything bare `GptMarkdown` would have
    // shown for the same final text.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(width: 400, child: GptMarkdown(full)),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    final referenceText =
        _richTextWidgets(tester).map((r) => r.text.toPlainText()).join();
    String alnum(String s) => s.replaceAll(RegExp('[^a-zA-Z0-9]'), '');
    final finalMatches = alnum(renderedTexts) == alnum(referenceText);

    // 2) no timer still pending 400ms after isStreaming goes false: pump
    //    400ms past completion, then unmount and pump further - a leaked
    //    Timer that still calls setState on the disposed State throws,
    //    which tester.takeException() would surface.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 2500));
    final timerLeakException = tester.takeException();
    final noPendingTimer = timerLeakException == null;

    // 3) words actually fade: sample alpha mid-growth on a fresh mount.
    var midDone = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: _HybridGrowing(
                full: full,
                chunkChars: chunkSize,
                onDone: () => midDone = true,
              ),
            ),
          ),
        ),
      ),
    );
    var sawSubOpaque = false;
    var midGuard = 0;
    while (!midDone && midGuard < 200) {
      await tester.pump(const Duration(milliseconds: 16));
      final alphas = _spanAlphas(tester);
      if (alphas.any((a) => a < 0.999)) {
        sawSubOpaque = true;
      }
      midGuard++;
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));

    final hybridQualifies = ratioB <= 1.8 && finalMatches && noPendingTimer;
    final decision = hybridQualifies ? 'HYBRID ADOPTED' : 'HYBRID REJECTED';

    final report =
        'delegation_benchmark ($rounds rounds, 400px, 16ms frames, doc '
        '${full.length} chars):\n'
        '  A ours            median ${results['A_ours']!.medianMicros}us, '
        'ratio ${ratioA.toStringAsFixed(3)}x, '
        '${results['A_ours']!.totalRebuilds} rebuilds\n'
        '  B hybrid (mock)   median ${results['B_hybrid']!.medianMicros}us, '
        'ratio ${ratioB.toStringAsFixed(3)}x, '
        '${results['B_hybrid']!.totalRebuilds} rebuilds\n'
        '  C full-delegation median ${results['C_full']!.medianMicros}us, '
        'ratio ${ratioC.toStringAsFixed(3)}x, '
        '${results['C_full']!.totalRebuilds} rebuilds\n'
        '  D bare            median ${results['D_bare']!.medianMicros}us '
        '(baseline)\n'
        '  E ours default (post-S5) median '
        '${results['E_defaultAfterS5']!.medianMicros}us, '
        'ratio ${ratioE.toStringAsFixed(3)}x, '
        '${results['E_defaultAfterS5']!.totalRebuilds} rebuilds\n'
        '  hybrid (mock) correctness: final==source=$finalMatches, '
        'noPendingTimerAt400ms=$noPendingTimer '
        '(exception: $timerLeakException), wordsActuallyFade=$sawSubOpaque\n'
        '  RULE on the ISOLATED MOCK (<=1.8x bare, final==source, no '
        'pending timer): $decision - but B1-S5 wired this into the REAL '
        '`StreamingText` (caret + engine + catch-up pacer) and it blew '
        'both budgets (~2.3x time, ~12.9x rebuilds) on '
        'stream_benchmark_test.dart - see doc/BENCHMARKS.md\'s "B1-S5 '
        'correction". The SHIPPED default (arm E) does NOT use the '
        'gpt_markdown hybrid animation; this is the real regression gate.';
    // ignore: avoid_print
    print(report);

    // Sanity only for A-D - every arm produced real samples. The
    // isolated-mock decision (adopt/reject) is recorded in
    // doc/BENCHMARKS.md, not gated here.
    expect(results['A_ours']!.frameMicros, isNotEmpty);
    expect(results['B_hybrid']!.frameMicros, isNotEmpty);
    expect(results['C_full']!.frameMicros, isNotEmpty);
    expect(results['D_bare']!.frameMicros, isNotEmpty);
    expect(sawSubOpaque, isTrue, reason: 'hybrid fade never went sub-opaque');

    // E IS gated (acceptance criterion 11: "the DEFAULT StreamingTextMarkdown
    // on a stream must be <=1.8x bare in BOTH benchmarks"): this is the
    // actual shipped default, measured with no overrides.
    expect(ratioE, lessThanOrEqualTo(1.8), reason: report);
  }, tags: ['benchmark']);
}
