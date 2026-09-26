// DESIGN.md section 7 ("Reduced motion") / acceptance criterion 9: when
// `MediaQuery.disableAnimations` is set (an OS/user "reduce motion"
// preference), the reveal must behave like `animationsEnabled: false` -
// instant, with a static (non-pulsing) caret and no fade - and it must react
// live if the setting changes mid-reveal.
//
// Today (main @ 38bc831) there is no reduced-motion handling anywhere in
// `lib/`, so a slow typing animation still plays out character by character
// regardless of this setting - this test fails there and passes after the
// fix.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_streaming_text_markdown/src/streaming/streaming_text.dart';

void main() {
  group('reduced motion', () {
    testWidgets('reveals instantly when disableAnimations is set at mount',
        (tester) async {
      const source = 'the quick brown fox jumps over the lazy dog';
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: StreamingText(
                text: source,
                markdownEnabled: false,
                showCursor: false,
                typingSpeed: const Duration(seconds: 5), // would take ages
              ),
            ),
          ),
        ),
      );

      // A single frame should be enough: reduced motion reveals instantly,
      // not over a 5-second-per-character typing animation.
      await tester.pump();
      await tester.pump();

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.data, source);
    });

    testWidgets('reacts when disableAnimations flips true mid-reveal',
        (tester) async {
      const source = 'the quick brown fox jumps over the lazy dog';
      Widget host({required bool disableAnimations}) => MediaQuery(
            data: MediaQueryData(disableAnimations: disableAnimations),
            child: MaterialApp(
              home: Scaffold(
                body: StreamingText(
                  text: source,
                  markdownEnabled: false,
                  showCursor: false,
                  typingSpeed: const Duration(milliseconds: 500),
                ),
              ),
            ),
          );

      await tester.pumpWidget(host(disableAnimations: false));
      await tester.pump(const Duration(milliseconds: 500));
      final partial = tester.widget<Text>(find.byType(Text)).data ?? '';
      expect(partial.length, lessThan(source.length));
      expect(partial, isNotEmpty);

      // Flip reduced motion on; the reveal should jump to completion rather
      // than continuing to crawl one character per 500ms.
      await tester.pumpWidget(host(disableAnimations: true));
      await tester.pump();
      await tester.pump();

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.data, source);
    });
  });
}
