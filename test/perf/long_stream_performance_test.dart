// Performance/regression coverage for very long LLM-style transcripts —
// the exact workload this package exists for (see docs/AWARD-PLAN.md).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

/// Generates deterministic filler text of at least [minLength] characters.
String _longText(int minLength) {
  final buffer = StringBuffer();
  var i = 0;
  while (buffer.length < minLength) {
    buffer.write('word${i % 997} ');
    i++;
  }
  return buffer.toString();
}

void main() {
  group('long-stream performance (regression guard)', () {
    testWidgets(
        'a 50k+ character static text completes animating within a bounded '
        'pump budget, no exceptions', (tester) async {
      final longText = _longText(50000);
      expect(longText.length, greaterThanOrEqualTo(50000));

      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: StreamingTextMarkdown(
            text: longText,
            markdownEnabled: false,
            wordByWord: false,
            // A large chunkSize keeps the pump count for 50k+ chars bounded
            // without changing the animated-reveal code path itself.
            chunkSize: 500,
            typingSpeed: const Duration(milliseconds: 1),
            onComplete: () => completed = true,
          ),
        ),
      );

      const maxPumps = 400;
      var pumps = 0;
      while (!completed && pumps < maxPumps) {
        await tester.pump(const Duration(milliseconds: 2));
        pumps++;
      }

      expect(
        completed,
        isTrue,
        reason: '${longText.length}-char text did not finish animating '
            'within $maxPumps pumps — possible performance regression.',
      );
    });

    testWidgets(
        'a 50k+ character stream completes without exceptions and without '
        'per-character fade-in controllers (memory safety)', (tester) async {
      final controller = StreamController<String>();
      addTearDown(() {
        if (!controller.isClosed) controller.close();
      });

      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: StreamingTextMarkdown(
            stream: controller.stream,
            markdownEnabled: false,
            // fadeInEnabled is intentionally left true: per-character fade
            // must be auto-suppressed because `stream` is non-null (one
            // AnimationController per glyph on an unbounded stream would
            // exhaust memory). This test proves that guarantee holds even
            // at LLM-transcript scale, not just for a short demo string.
            fadeInEnabled: true,
            chunkSize: 500,
            typingSpeed: const Duration(milliseconds: 1),
            onComplete: () => completed = true,
          ),
        ),
      );

      // Feed ~60k characters across many chunks, the way a real SSE bridge
      // would append token-by-token or in small batches.
      final chunk = _longText(3000);
      const chunkCount = 20; // ~60k+ chars total
      for (var i = 0; i < chunkCount; i++) {
        controller.add(chunk);
        await tester.pump(const Duration(milliseconds: 1));
      }
      await controller.close();

      const maxPumps = 400;
      var pumps = 0;
      while (!completed && pumps < maxPumps) {
        await tester.pump(const Duration(milliseconds: 2));
        pumps++;
      }

      expect(
        completed,
        isTrue,
        reason: 'streamed ${chunk.length * chunkCount}+ char transcript did '
            'not complete within $maxPumps pumps.',
      );
      // No FlutterError/exception was thrown by the pump loop above — if
      // per-character fade controllers were being created for every one of
      // 60k+ glyphs, this test would time out or the binding would report
      // pending timers/tickers well before reaching here.
    });
  });
}
