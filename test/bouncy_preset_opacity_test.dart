import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

void main() {
  testWidgets(
    'bouncy preset: every character reaches full opacity once typing completes',
    (WidgetTester tester) async {
      // Reproduces the demo's "bouncy" preset text (2026-09-03 QA pass): the
      // em-dash intermittently rendered invisible ("...markdown — a package"
      // showed a blank double-space gap) even though typing had finished.
      // Real devices hit this under frame-timing jitter that a test's exact
      // virtual clock doesn't reproduce, so this asserts the actual
      // guarantee instead: once the widget reports itself complete, no
      // per-character Opacity may still read below fully visible.
      const text =
          'flutter_streaming_text_markdown — a package for streaming text.';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingTextMarkdown.fromPreset(
              text: text,
              preset: LLMAnimationPresets.bouncy,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(milliseconds: 60));

      // The em-dash itself must be present and rendered as plain text.
      expect(find.text('—'), findsOneWidget);

      // No character may still be sitting behind a partial Opacity once the
      // animation has settled.
      final opacityWidgets = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .toList(growable: false);
      for (final opacity in opacityWidgets) {
        expect(
          opacity.opacity,
          1.0,
          reason: 'a character is still rendering below full opacity '
              'after the streaming animation completed',
        );
      }
    },
  );
}
