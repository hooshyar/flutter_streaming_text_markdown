// B1-S5 / acceptance criterion 10: pacing defaults.
//
// - `Stream<String>` input defaults to [StreamPacing.catchUp] (DESIGN.md
//   4.3: a 400-char burst is fully revealed within ~1.0s, well ahead of the
//   old one-unit-per-tick behaviour).
// - Static `text` input defaults to [StreamPacing.fixed] using the widget's
//   own `typingSpeed` (unchanged, one-word-per-tick pacing).
// - An explicit `pacing:` override always wins, on either input kind.
//
// Today (pre-B1-S5) there is no `pacing` parameter and [RevealScheduler]'s
// pacer always defaults to `FixedPacer` regardless of `stream` - so a burst
// arriving on an open stream drains no faster than static text at the same
// `typingSpeed`. This file fails to compile against main @ 8fd8f79 (no
// `pacing`/`StreamPacing`) and, once made to compile against a stub, would
// fail on timing: this is the reproduction that motivates the feature.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

import '../support/frames.dart';

String _revealedPlainText(WidgetTester tester) {
  final text = tester.widget<Text>(find.byType(Text));
  return text.data ?? text.textSpan?.toPlainText() ?? '';
}

void main() {
  group('pacing defaults (acceptance criterion 10)', () {
    testWidgets('stream input defaults to catch-up pacing: a 400-char burst is '
        'fully revealed within ~1.0s', (tester) async {
      final burst = List.generate(
        80,
        (i) => 'word$i',
      ).join(' '); // ~400 chars incl. spaces
      expect(burst.length, greaterThanOrEqualTo(390));

      final controller = StreamController<String>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: '',
              stream: controller.stream,
              markdownEnabled: false,
              showCursor: false,
            ),
          ),
        ),
      );
      await tester.pump();

      controller.add(burst);
      await controller.close();

      // DESIGN.md 4.3: fully revealed within ~1.0s of the burst landing.
      await pumpFor(tester, const Duration(milliseconds: 1000));
      // A little extra grace for the drain-on-close ramp (400ms + one
      // window past the deadline, per CatchUpPacer's own contract).
      await pumpFor(tester, const Duration(milliseconds: 500));

      expect(_revealedPlainText(tester), burst);
    });

    testWidgets(
      'stream input catches up much faster than the same content would '
      'reveal under a fixed one-word-per-tick pacer',
      (tester) async {
        final burst = List.generate(80, (i) => 'word$i').join(' ');

        final controller = StreamController<String>();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamingText(
                text: '',
                stream: controller.stream,
                markdownEnabled: false,
                showCursor: false,
                pacing: const StreamPacing.fixed(Duration(milliseconds: 50)),
              ),
            ),
          ),
        );
        await tester.pump();
        controller.add(burst);
        await controller.close();

        // Same 1.5s budget the catch-up default fully drains within - the
        // explicit fixed pacer, revealing one word per 50ms tick, must NOT
        // have finished a 80-word burst yet (80 words * 50ms = 4s).
        await pumpFor(tester, const Duration(milliseconds: 1500));
        expect(_revealedPlainText(tester), isNot(burst));
      },
    );

    testWidgets(
      'static text input defaults to fixed pacing at typingSpeed (unchanged '
      'one-unit-per-tick behaviour)',
      (tester) async {
        const source = 'one two three four five six seven eight nine ten';
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StreamingText(
                text: source,
                markdownEnabled: false,
                showCursor: false,
                wordByWord: true,
                typingSpeed: Duration(milliseconds: 100),
              ),
            ),
          ),
        );
        await tester.pump();

        // Word-by-word, one word per 100ms tick with `smoothFade`'s default
        // WordPolicy: after ~350ms (3.5 ticks) only a handful of the ten
        // words should be visible - a catch-up pacer would instead dump the
        // whole (tiny) backlog in the very first ~50ms window.
        await pumpFor(tester, const Duration(milliseconds: 350));
        final partial = _revealedPlainText(tester);
        expect(partial, isNot(source));
        expect(partial.length, lessThan(source.length));

        await pumpFor(tester, const Duration(milliseconds: 1500));
        expect(_revealedPlainText(tester), source);
      },
    );
  });
}
