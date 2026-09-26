// Ratio-based performance benchmark (acceptance criterion 8): a growing
// 20k-char markdown stream must stay within 1.8x of bare `GptMarkdown`
// (target ~1.3x), measured over 150 frames, interleaved so JIT warmup, GC
// pauses and scheduling jitter land on both sides roughly equally rather
// than skewing one engine's numbers.
//
// This is a wall-clock benchmark, not a correctness test - it is the one
// sanctioned wall-clock assertion in the suite (acceptance criterion 11) and
// is tagged `benchmark` (see dart_test.yaml) so it's excluded from the
// default `flutter test` run and only executed on demand
// (`flutter test --tags benchmark`) or in the dedicated CI job.
//
// Numbers observed on this machine are recorded in doc/BENCHMARKS.md.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'package:flutter_streaming_text_markdown/src/streaming/streaming_text.dart';

/// Hosts a piece of growable text and exposes [grow] so a test can update it
/// via `setState` without tearing down and remounting the subtree - the
/// point being to measure each *incremental* rebuild, not a fresh mount.
class _Growing extends StatefulWidget {
  const _Growing({super.key, required this.builder});

  final Widget Function(BuildContext context, String text) builder;

  @override
  State<_Growing> createState() => _GrowingState();
}

class _GrowingState extends State<_Growing> {
  String _text = '';

  void grow(String next) => setState(() => _text = next);

  @override
  Widget build(BuildContext context) => widget.builder(context, _text);
}

String _chunk(int i) =>
    'Paragraph $i: some **bold** and _italic_ words, an `inline code` '
    'span, and a [link](https://example.com/$i) describing streamed item '
    '$i in a growing answer.\n\n';

void main() {
  testWidgets(
    'a growing 20k-char markdown doc stays within 1.8x of bare GptMarkdown '
    '(median, interleaved, 400px wide)',
    (tester) async {
      final oursKey = GlobalKey<_GrowingState>();
      final bareKey = GlobalKey<_GrowingState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    width: 400,
                    child: _Growing(
                      key: oursKey,
                      builder: (context, text) => StreamingText(
                        text: text,
                        animationsEnabled: false,
                        showCursor: false,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 400,
                    child: _Growing(
                      key: bareKey,
                      builder: (context, text) => GptMarkdown(text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      const targetFrames = 150;
      const frameBudget = Duration(milliseconds: 16);
      final oursMicros = <int>[];
      final bareMicros = <int>[];
      final buffer = StringBuffer();
      final stopwatch = Stopwatch();

      var i = 0;
      while (i < targetFrames && buffer.length < 20000) {
        buffer.write(_chunk(i));
        final text = buffer.toString();

        stopwatch
          ..reset()
          ..start();
        oursKey.currentState!.grow(text);
        await tester.pump(frameBudget);
        stopwatch.stop();
        oursMicros.add(stopwatch.elapsedMicroseconds);

        stopwatch
          ..reset()
          ..start();
        bareKey.currentState!.grow(text);
        await tester.pump(frameBudget);
        stopwatch.stop();
        bareMicros.add(stopwatch.elapsedMicroseconds);

        i++;
      }

      oursMicros.sort();
      bareMicros.sort();
      final oursMedian = oursMicros[oursMicros.length ~/ 2];
      final bareMedian = bareMicros[bareMicros.length ~/ 2];
      final ratio = bareMedian == 0 ? 1.0 : oursMedian / bareMedian;

      final report =
          'stream_benchmark: ${oursMicros.length} interleaved frames, '
          'final doc ${buffer.length} chars — ours median ${oursMedian}us, '
          'bare GptMarkdown median ${bareMedian}us, ratio '
          '${ratio.toStringAsFixed(3)}x (budget <= 1.8x, target ~1.3x)';
      // ignore: avoid_print
      print(report);

      expect(ratio, lessThanOrEqualTo(1.8), reason: report);
    },
    tags: ['benchmark'],
  );
}
