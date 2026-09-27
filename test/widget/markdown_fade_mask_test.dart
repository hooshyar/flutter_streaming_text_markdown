// B1-S6: a cheap, paint-only word-fade for MARKDOWN under
// `RevealMode.smoothFade`/`RevealMode.wordFade`.
//
// `gpt_markdown`'s own `animation: fade` was measured (doc/BENCHMARKS.md,
// "Reveal delegation decision"/"B1-S5 correction") at 2.1-2.2x time and 13x
// element rebuilds against a 1.8x/6x budget, so `smoothFade` markdown ships
// with NO alpha animation at all pre-S6 (see `smooth_fade_test.dart`'s
// "markdown: reveals word-paced" test). This slice adds one back via
// [MarkdownFadeMask] - a [RenderProxyBox]-level paint mask that finds the
// on-screen box(es) of the still-fading suffix and dims only those pixels,
// never touching an `Element` or re-running `gpt_markdown`'s segment cache.
//
// These tests probe [RenderMarkdownFadeMask.debugActiveDims] directly
// instead of screenshots - it returns exactly the (rect, alpha) pairs
// `paint()` is about to draw, so the fade curve is asserted the same way
// `smooth_fade_test.dart` asserts it for plain text (via leaf-span alphas),
// just at the render-object level instead of the widget-span level.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'package:flutter_streaming_text_markdown/src/render/markdown_fade_mask.dart';
import 'package:flutter_test/flutter_test.dart';

/// All currently-active dim alphas, oldest run first (matches
/// [RenderMarkdownFadeMask.debugActiveDims]'s order).
List<double> _activeAlphas(WidgetTester tester) {
  final renderObject = tester.renderObject<RenderMarkdownFadeMask>(
    find.byType(MarkdownFadeMask),
  );
  return renderObject.debugActiveDims().map((d) => d.$2).toList();
}

/// Pumps fixed 16ms frames (the shared fade clock is ticker-driven, see
/// `smooth_fade_test.dart`'s file header - a durationless `pump()` would
/// never advance it) until the ticker itself reports nothing left to
/// animate, sampling [sample] after every pumped frame.
Future<List<T>> _pumpUntilSettled<T>(
  WidgetTester tester,
  T Function() sample, {
  int maxFrames = 20000,
}) async {
  final samples = <T>[sample()];
  var i = 0;
  while (tester.binding.hasScheduledFrame && i < maxFrames) {
    await tester.pump(const Duration(milliseconds: 16));
    samples.add(sample());
    i++;
  }
  return samples;
}

String _revealedPlainText(WidgetTester tester) {
  final buffer = StringBuffer();
  for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
    buffer.write(rt.text.toPlainText());
  }
  return buffer.toString();
}

void main() {
  group('B1-S6 markdown fade (MarkdownFadeMask)', () {
    testWidgets(
      'smoothFade markdown: a MarkdownFadeMask is present and its active '
      'dim alpha rises from sub-opaque toward 1.0 within ~180ms',
      (tester) async {
        // A single unspaced "word" (mirrors smooth_fade_test.dart's plain-
        // text test): exactly one fade run is ever in flight for the whole
        // sampling window, so its alpha can be tracked in isolation without
        // a second, fresher run appearing mid-sample and making "the last
        // active run" jump between different runs.
        const word = 'alphabravocharliedeltaecho';
        final controller = StreamController<String>();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamingText(
                text: '',
                stream: controller.stream,
                markdownEnabled: true,
                showCursor: false,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(MarkdownFadeMask), findsOneWidget);

        // Trailing space closes the word (WordPolicy withholds an
        // unterminated word while input is open). Close the stream right
        // away too - nothing else will ever grow this source, so the
        // scheduler settles into idle purely from the reveal completing,
        // and [_pumpUntilSettled] below terminates from the fade alone
        // finishing rather than looping on an open stream forever.
        controller.add('$word ');
        await controller.close();
        await tester.pump(const Duration(milliseconds: 50));

        final earlyAlphas = _activeAlphas(tester);
        expect(
          earlyAlphas,
          isNotEmpty,
          reason: 'freshly-revealed markdown text must have an active fade',
        );
        expect(
          earlyAlphas.any((a) => a < 0.999),
          isTrue,
          reason: 'a freshly-revealed run must start sub-opaque',
        );

        // Track monotonicity of the single active run's alpha, pumping real
        // frames (see [_pumpUntilSettled]) until the ticker itself reports
        // nothing left to animate - i.e. the fade has genuinely settled,
        // not just "180 fake milliseconds elapsed".
        final rawSamples = await _pumpUntilSettled(
          tester,
          () => _activeAlphas(tester),
        );
        final samples = [
          for (final alphas in rawSamples)
            if (alphas.isNotEmpty) alphas.first,
        ];
        expect(samples, isNotEmpty);
        for (var i = 1; i < samples.length; i++) {
          expect(
            samples[i],
            greaterThanOrEqualTo(samples[i - 1] - 1e-9),
            reason: 'alpha must never decrease (sample $i): $samples',
          );
        }

        // Once settled, nothing should still be active. `gpt_markdown`
        // renders the source's trailing space as zero-width whitespace (it
        // doesn't show up in `RichText.text.toPlainText()`), so compare
        // against the word only - the mask itself never drops or duplicates
        // characters (`total`/`getBoxesForSelection` above already prove
        // that indirectly: this assertion is about `gpt_markdown`'s own
        // rendering, not the mask).
        expect(_activeAlphas(tester), isEmpty);
        expect(_revealedPlainText(tester), word);
      },
    );

    testWidgets('settled (non-trailing) text is never dimmed', (tester) async {
      const source = 'alpha bravo charlie delta echo foxtrot golf hotel';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: source,
              markdownEnabled: true,
              showCursor: false,
              typingSpeed: Duration(milliseconds: 16),
            ),
          ),
        ),
      );
      await tester.pump();

      // Reveal well past the fade window's worth of the FIRST word, then
      // reveal more - the run for that first word must have fully expired
      // (no longer present in the active-dim list) by the time later words
      // are still fading.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final renderObject = tester.renderObject<RenderMarkdownFadeMask>(
        find.byType(MarkdownFadeMask),
      );
      final dims = renderObject.debugActiveDims();
      // Every still-active dim rect must lie in the trailing portion of the
      // paragraph - i.e. none of them can be anywhere near x=0 (where
      // "alpha", the first word, renders), once several words have already
      // streamed past the fade window.
      for (final (rect, _) in dims) {
        expect(
          rect.left,
          greaterThan(0.0),
          reason: 'the first word must have settled by now: $dims',
        );
      }

      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(_revealedPlainText(tester), source);
    });

    testWidgets('no MarkdownFadeMask under reduced motion', (tester) async {
      const source = 'alpha bravo charlie';
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: StreamingText(
                text: source,
                markdownEnabled: true,
                showCursor: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(MarkdownFadeMask), findsNothing);
      expect(_revealedPlainText(tester), source);
    });

    testWidgets('no MarkdownFadeMask under revealMode: null (legacy)', (
      tester,
    ) async {
      const source = 'alpha bravo charlie';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: source,
              markdownEnabled: true,
              revealMode: null,
              showCursor: false,
            ),
          ),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.byType(MarkdownFadeMask), findsNothing);
    });

    testWidgets('no MarkdownFadeMask under RevealMode.typewriter/instant', (
      tester,
    ) async {
      const source = 'alpha bravo charlie';
      for (final mode in [RevealMode.typewriter, RevealMode.instant]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamingText(
                text: source,
                markdownEnabled: true,
                revealMode: mode,
                showCursor: false,
              ),
            ),
          ),
        );
        await tester.pump();
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(find.byType(MarkdownFadeMask), findsNothing, reason: '$mode');
      }
    });

    testWidgets(
      'RTL/Arabic markdown streams without exceptions and settles opaque',
      (tester) async {
        const source = 'مرحبا بالعالم كيف حالك اليوم';
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StreamingText(
                text: source,
                markdownEnabled: true,
                showCursor: false,
                typingSpeed: Duration(milliseconds: 16),
              ),
            ),
          ),
        );
        await tester.pump();
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        // Mid-stream a fade may well be active - just must not throw.
        expect(tester.takeException(), isNull);
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(tester.takeException(), isNull);
        expect(_revealedPlainText(tester), source);
      },
    );

    testWidgets(
      'a growing code fence streams without exceptions under the mask',
      (tester) async {
        const source = '''
Here is some code:

```dart
void main() {
  print('hello');
}
```

All done.''';
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StreamingText(
                text: source,
                markdownEnabled: true,
                showCursor: false,
                typingSpeed: Duration(milliseconds: 8),
              ),
            ),
          ),
        );
        await tester.pump();
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 8));
          expect(tester.takeException(), isNull);
        }
        for (var i = 0; i < 200; i++) {
          await tester.pump(const Duration(milliseconds: 8));
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('markdown smoothFade: at most 2 transient tickers', (
      tester,
    ) async {
      const source = 'alpha bravo charlie delta echo foxtrot';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: source,
              markdownEnabled: true,
              showCursor: true,
              typingSpeed: Duration(milliseconds: 16),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.transientCallbackCount, lessThanOrEqualTo(2));

      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(_revealedPlainText(tester), source);
    });
  });
}
