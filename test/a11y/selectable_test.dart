// Acceptance criterion 9: `selectable` wraps the rendered content in a
// `SelectionArea`, and tap-to-complete must still work when it's on.
//
// Today (main @ 38bc831) `selectable` is accepted but never used anywhere in
// `_buildContent` - the field is dead. This test fails there (no
// `SelectionArea` in the tree) and passes after the fix.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_streaming_text_markdown/src/streaming/streaming_text.dart';

void main() {
  group('selectable', () {
    testWidgets('wraps content in a SelectionArea', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreamingText(
              revealMode: null,
              text: 'select me',
              markdownEnabled: false,
              showCursor: false,
              animationsEnabled: false,
              selectable: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SelectionArea), findsOneWidget);
    });

    testWidgets('does not add a SelectionArea when selectable is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreamingText(
              revealMode: null,
              text: 'select me',
              markdownEnabled: false,
              showCursor: false,
              animationsEnabled: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SelectionArea), findsNothing);
    });

    testWidgets('tap-to-complete still works when selectable is on', (
      tester,
    ) async {
      const source = 'the quick brown fox jumps over the lazy dog';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingText(
              revealMode: null,
              text: source,
              markdownEnabled: false,
              showCursor: false,
              selectable: true,
              typingSpeed: const Duration(milliseconds: 200),
            ),
          ),
        ),
      );
      // Reveal a little content first so there's non-zero size to tap (an
      // empty `Text` lays out at zero width/height).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final partial = tester.widget<Text>(find.byType(Text)).data ?? '';
      expect(partial, isNotEmpty);
      expect(partial.length, lessThan(source.length));

      await tester.tap(find.byType(StreamingText));
      await tester.pump();
      await tester.pump();

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.data, source);
    });
  });
}
