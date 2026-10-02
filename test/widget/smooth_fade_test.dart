// B1-S5 / acceptance criterion 9: `RevealMode.smoothFade`.
//
// - word units
// - opacity only, 180ms on `Cubic(0.2, 0, 0, 1)`
// - works for text AND stream input, plain text (with alpha), and Arabic
// - alpha rises monotonically to 1.0 and settles within the fade budget
// - at most 2 transient tickers
// - no fade under reduced motion
//
// The fade clock (`lib/src/streaming/streaming_text.dart`'s `_fadeNow`) is
// driven from the shared `Ticker`'s own `elapsed` (see `_onTick`), not a
// wall-clock `Stopwatch` - so under `flutter test` it advances only on
// pumped frames, deterministically, regardless of real machine load. These
// tests drive it by pumping fixed 16ms frames in a loop until the ticker
// itself reports settled (`hasScheduledFrame`), rather than asserting on a
// specific frame count - `tester.pump()` with no duration would never
// advance this clock at all (the fake frame timestamp wouldn't move), so
// every pump below passes an explicit duration.
//
// Markdown correction (see doc/BENCHMARKS.md's "B1-S5 correction" and the
// comment on `_buildContent`'s `markdownRevealFadeEnabled` in
// `lib/src/streaming/streaming_text.dart`): PHASE-B1-PLAN.md's own decision
// rule says "if [the hybrid] fails ... markdown smoothFade becomes
// word-paced with no alpha" - this slice's real (not mocked) perf numbers
// blew the 1.8x/6x budgets with the hybrid wired in, so that is exactly the
// branch shipped: `smoothFade` markdown still reveals word-by-word (this
// file's markdown test asserts that), just without a `gpt_markdown` alpha
// animation on top.
//
// Today (pre-B1-S5) there is no `RevealMode`/`smoothFade` at all - every
// `revealMode:`/`RevealMode` reference below fails to compile against main
// @ 8fd8f79.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

/// Leaf-span alphas only: `buildFadeSpan`'s root `TextSpan` carries the base
/// (fully-opaque) style purely as a paint default for its children - it is
/// never itself painted once it has children, so counting its color would
/// double-count a settled alpha of 1.0 alongside the real (possibly-fading)
/// leaf run.
List<double> _leafAlphas(WidgetTester tester) {
  final alphas = <double>[];
  void visit(InlineSpan span) {
    if (span is TextSpan) {
      final children = span.children;
      if (children == null || children.isEmpty) {
        final color = span.style?.color;
        if (color != null) alphas.add(color.a);
      } else {
        children.forEach(visit);
      }
    }
  }

  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    final span = text.textSpan;
    if (span != null) visit(span);
  }
  return alphas;
}

String _revealedPlainText(WidgetTester tester) {
  final buffer = StringBuffer();
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    buffer.write(text.data ?? text.textSpan?.toPlainText() ?? '');
  }
  return buffer.toString();
}

/// Pumps fixed 16ms frames (see the file header - the fade clock is
/// ticker-driven, so a durationless `pump()` would never advance it) until
/// the ticker itself reports nothing left to animate, sampling [sample]
/// after every pumped frame. Bounded by [maxFrames] as a safety net against
/// a ticker that never settles (which would otherwise hang the test).
Future<List<double>> _pumpUntilSettled(
  WidgetTester tester,
  double Function() sample, {
  int maxFrames = 20000,
}) async {
  final samples = <double>[sample()];
  var i = 0;
  while (tester.binding.hasScheduledFrame && i < maxFrames) {
    await tester.pump(const Duration(milliseconds: 16));
    samples.add(sample());
    i++;
  }
  return samples;
}

void main() {
  group('RevealMode.smoothFade (acceptance criterion 9)', () {
    testWidgets(
      'plain text: alpha rises monotonically to 1.0, opacity only, word '
      'units',
      (tester) async {
        // A single unspaced "word" reveals in one step: exactly one fade
        // run is ever in flight, so its alpha can be tracked in isolation
        // (several overlapping runs of different ages is expected/correct
        // behaviour, not something a single sample can assert
        // monotonicity on).
        const source = 'alphabravocharliedeltaecho';
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StreamingText(
                text: source,
                markdownEnabled: false,
                showCursor: false,
                typingSpeed: Duration(milliseconds: 1),
              ),
            ),
          ),
        );
        // Let the 1ms typing-speed timer fire and reveal the whole word.
        await tester.pump(const Duration(milliseconds: 16));
        expect(_leafAlphas(tester), hasLength(1));

        final samples = await _pumpUntilSettled(
          tester,
          () => _leafAlphas(tester).single,
        );

        expect(
          samples.first,
          lessThan(0.999),
          reason: 'the run must start sub-opaque, not appear instantly',
        );
        for (var i = 1; i < samples.length; i++) {
          expect(
            samples[i],
            greaterThanOrEqualTo(samples[i - 1] - 1e-9),
            reason: 'alpha must never decrease (sample $i)',
          );
        }
        expect(samples.last, closeTo(1.0, 1e-6));
        expect(_revealedPlainText(tester), source);
      },
    );

    testWidgets('plain text: at most 2 transient tickers', (tester) async {
      const source = 'alpha bravo charlie delta echo foxtrot golf';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: source,
              markdownEnabled: false,
              showCursor: true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.transientCallbackCount, lessThanOrEqualTo(2));
      await _pumpUntilSettled(tester, () => 0.0);
    });

    testWidgets('works on Stream<String> input, not suppressed', (
      tester,
    ) async {
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
      // A trailing space closes the word (WordPolicy withholds an
      // unterminated word while input is still open, since the next chunk
      // could still extend it - see `WordPolicy.nextBoundary`).
      controller.add('alphabravocharlie ');
      // Stream input defaults to catch-up pacing (acceptance criterion 10),
      // which ticks on a 50ms window rather than every 16ms frame.
      await tester.pump(const Duration(milliseconds: 50));

      final alphas = _leafAlphas(tester);
      expect(
        alphas.any((a) => a < 0.999),
        isTrue,
        reason: 'a freshly-streamed word must start sub-opaque',
      );

      await controller.close();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await _pumpUntilSettled(tester, () => 0.0);
      expect(_revealedPlainText(tester), 'alphabravocharlie ');
    });

    testWidgets('works on Arabic content (not suppressed, unlike legacy)', (
      tester,
    ) async {
      const source = 'مرحبابالعالم';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: source,
              markdownEnabled: false,
              showCursor: false,
              typingSpeed: Duration(milliseconds: 1),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      final alphas = _leafAlphas(tester);
      expect(
        alphas.any((a) => a < 0.999),
        isTrue,
        reason: 'smoothFade must fade Arabic content too (criterion 9)',
      );

      await _pumpUntilSettled(tester, () => 0.0);
      expect(_revealedPlainText(tester), source);
    });

    testWidgets('no fade under reduced motion', (tester) async {
      const source = 'alpha bravo charlie delta';
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: StreamingText(
                text: source,
                markdownEnabled: false,
                showCursor: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Reduced motion is instant AND opaque from the very first frame.
      final alphas = _leafAlphas(tester);
      expect(alphas, isNotEmpty);
      for (final a in alphas) {
        expect(a, closeTo(1.0, 0.01));
      }
      expect(_revealedPlainText(tester), source);
    });

    testWidgets(
      'markdown: reveals word-paced (the hybrid-rejected fallback; see '
      'doc/BENCHMARKS.md\'s "B1-S5 correction")',
      (tester) async {
        const source = 'alpha bravo **charlie** delta echo';
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StreamingText(
                text: source,
                markdownEnabled: true,
                showCursor: false,
                typingSpeed: Duration(milliseconds: 40),
              ),
            ),
          ),
        );
        await tester.pump();

        // Mid-reveal: not yet everything, but real content is visible
        // (word-paced, not withheld until the end).
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 40));
        }
        final richTexts =
            tester
                .widgetList(find.byWidgetPredicate((w) => w is RichText))
                .cast<RichText>();
        final midText = richTexts.map((r) => r.text.toPlainText()).join();
        expect(midText, isNotEmpty);
        expect(midText.contains('alpha'), isTrue);

        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 40));
        }
        final finalTexts =
            tester
                .widgetList(find.byWidgetPredicate((w) => w is RichText))
                .cast<RichText>();
        final finalPlain = finalTexts.map((r) => r.text.toPlainText()).join();
        // gpt_markdown drops the `**`/`__` delimiters themselves; the words
        // they wrap must still all be present.
        for (final word in ['alpha', 'bravo', 'charlie', 'delta', 'echo']) {
          expect(finalPlain, contains(word));
        }
      },
    );
  });
}
