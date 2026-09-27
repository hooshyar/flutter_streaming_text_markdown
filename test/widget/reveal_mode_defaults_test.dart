// B1-S5 / acceptance criterion 8: `RevealMode` defaults.
//
// - `RevealMode {smoothFade, wordFade, typewriter, instant}` is exported.
// - `StreamingText` and `StreamingTextMarkdown`'s default, `.chatGPT` and
//   `.claude` constructors default to `RevealMode.smoothFade`.
// - `.typewriter()` and `.instant()` map to their own matching mode.
// - An explicit `revealMode: null` gives the legacy 1.x behaviour (and is
//   forwarded through unchanged, not silently upgraded to a default).
//
// Today (pre-B1-S5) there is no `revealMode` parameter and no `RevealMode`
// export at all, so every expectation below fails to even compile against
// main @ 8fd8f79 - this is the reproduction that motivates the feature.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'package:flutter_streaming_text_markdown/src/streaming/streaming_text.dart';

void main() {
  group('RevealMode defaults (acceptance criterion 8)', () {
    testWidgets('StreamingText defaults to smoothFade', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StreamingText(text: 'hello world')),
        ),
      );
      final widget = tester.widget<StreamingText>(find.byType(StreamingText));
      expect(widget.revealMode, RevealMode.smoothFade);
    });

    testWidgets(
      'StreamingTextMarkdown default constructor defaults to smoothFade',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: StreamingTextMarkdown(text: 'hello world')),
          ),
        );
        final outer = tester.widget<StreamingTextMarkdown>(
          find.byType(StreamingTextMarkdown),
        );
        expect(outer.revealMode, RevealMode.smoothFade);
        final inner = tester.widget<StreamingText>(find.byType(StreamingText));
        expect(inner.revealMode, RevealMode.smoothFade);
      },
    );

    testWidgets('StreamingTextMarkdown.chatGPT defaults to smoothFade', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreamingTextMarkdown.chatGPT(text: 'hello world'),
          ),
        ),
      );
      final outer = tester.widget<StreamingTextMarkdown>(
        find.byType(StreamingTextMarkdown),
      );
      expect(outer.revealMode, RevealMode.smoothFade);
    });

    testWidgets('StreamingTextMarkdown.claude defaults to smoothFade', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreamingTextMarkdown.claude(text: 'hello world'),
          ),
        ),
      );
      final outer = tester.widget<StreamingTextMarkdown>(
        find.byType(StreamingTextMarkdown),
      );
      expect(outer.revealMode, RevealMode.smoothFade);
    });

    testWidgets('StreamingTextMarkdown.typewriter defaults to typewriter', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreamingTextMarkdown.typewriter(text: 'hello world'),
          ),
        ),
      );
      final outer = tester.widget<StreamingTextMarkdown>(
        find.byType(StreamingTextMarkdown),
      );
      expect(outer.revealMode, RevealMode.typewriter);
    });

    testWidgets('StreamingTextMarkdown.instant defaults to instant', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreamingTextMarkdown.instant(text: 'hello world'),
          ),
        ),
      );
      final outer = tester.widget<StreamingTextMarkdown>(
        find.byType(StreamingTextMarkdown),
      );
      expect(outer.revealMode, RevealMode.instant);
    });

    testWidgets(
      'an explicit revealMode: null is forwarded unchanged (legacy 1.x)',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StreamingTextMarkdown(
                revealMode: null,
                text: 'hello world',
              ),
            ),
          ),
        );
        final outer = tester.widget<StreamingTextMarkdown>(
          find.byType(StreamingTextMarkdown),
        );
        expect(outer.revealMode, isNull);
        final inner = tester.widget<StreamingText>(find.byType(StreamingText));
        expect(inner.revealMode, isNull);
      },
    );

    testWidgets(
      'an explicit revealMode override on StreamingTextMarkdown.chatGPT wins',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StreamingTextMarkdown.chatGPT(
                revealMode: RevealMode.wordFade,
                text: 'hello world',
              ),
            ),
          ),
        );
        final outer = tester.widget<StreamingTextMarkdown>(
          find.byType(StreamingTextMarkdown),
        );
        expect(outer.revealMode, RevealMode.wordFade);
      },
    );
  });
}
