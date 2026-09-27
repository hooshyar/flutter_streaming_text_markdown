// Acceptance criterion 9: mid-stream text is excluded from semantics (so a
// screen reader doesn't read every partial revision as it grows), there is
// exactly one announcement on completion, and a supplied `semanticsLabel`
// replaces the raw text node entirely.
//
// Today (main @ 38bc831) the widget has no `Semantics`/`ExcludeSemantics`
// wrapping at all, so partial text IS exposed to the semantics tree while
// revealing and no completion announcement is ever sent - these tests fail
// there and pass after the fix.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_streaming_text_markdown/src/streaming/streaming_text.dart';

void main() {
  group('semantics', () {
    testWidgets('partial text is excluded from semantics while revealing', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      const source = 'hello world';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingText(
              revealMode: null,
              text: source,
              markdownEnabled: false,
              showCursor: false,
              typingSpeed: const Duration(milliseconds: 200),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final partial = tester.widget<Text>(find.byType(Text)).data ?? '';
      expect(partial, isNotEmpty);
      expect(partial.length, lessThan(source.length));

      // The partial text must not be reachable via its semantics label.
      expect(find.bySemanticsLabel(partial), findsNothing);

      // `addTearDown` runs too late for the framework's own
      // "no leaked SemanticsHandle" check, so dispose explicitly.
      handle.dispose();
    });

    testWidgets('exactly one announcement fires on completion', (tester) async {
      const source = 'hello world';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreamingText(
              revealMode: null,
              text: source,
              markdownEnabled: false,
              showCursor: false,
              animationsEnabled: false,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final announcements = tester.takeAnnouncements();
      expect(announcements, hasLength(1));
      expect(announcements.single.message, source);

      // A further rebuild with the same (already-complete) source must not
      // announce again.
      await tester.pump();
      expect(tester.takeAnnouncements(), isEmpty);
    });

    testWidgets('semanticsLabel replaces the raw text node', (tester) async {
      final handle = tester.ensureSemantics();

      const source = 'raw revealed text';
      const label = 'friendly label';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreamingText(
              revealMode: null,
              text: source,
              markdownEnabled: false,
              showCursor: false,
              animationsEnabled: false,
              semanticsLabel: label,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.bySemanticsLabel(label), findsOneWidget);
      expect(find.bySemanticsLabel(source), findsNothing);

      handle.dispose();
    });
  });
}
