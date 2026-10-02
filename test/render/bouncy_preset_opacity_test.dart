import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

/// Recursively asserts that no [TextSpan] in [span] is still sitting behind
/// a partial-opacity fade (a non-null, non-fully-opaque color).
void _expectFullyOpaque(InlineSpan span) {
  if (span is TextSpan) {
    final color = span.style?.color;
    if (color != null) {
      expect(
        color.a,
        1.0,
        reason:
            'a character is still rendering below full opacity '
            'after the streaming animation completed',
      );
    }
    span.children?.forEach(_expectFullyOpaque);
  }
}

void main() {
  testWidgets(
    'bouncy preset: every character reaches full opacity once typing completes',
    (WidgetTester tester) async {
      // Reproduces the demo's "bouncy" preset text (2026-09-03 QA pass): the
      // em-dash intermittently rendered invisible ("...markdown — a package"
      // showed a blank double-space gap) even though typing had finished.
      //
      // With the engine rewrite (S5), a plain-text fade no longer renders one
      // `Text` widget per word/character with its own `AnimationController` —
      // it renders a single `Text.rich(buildFadeSpan(...))` driven by one
      // `Ticker` (see `lib/src/render/fade_span.dart`). So this now asserts
      // the equivalent, single-ticker-era guarantee directly: once the
      // widget reports itself complete, the combined plain text still
      // contains the em-dash, and no span in the fade tree may still read
      // below full opacity.
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

      final texts = tester.widgetList<Text>(find.byType(Text)).toList();
      final combined =
          texts.map((t) => t.textSpan?.toPlainText() ?? t.data ?? '').join();
      expect(
        combined,
        contains('—'),
        reason: 'the em-dash must be present in the settled output',
      );

      for (final t in texts) {
        final span = t.textSpan;
        if (span != null) _expectFullyOpaque(span);
      }

      // No character may still be sitting behind a partial Opacity widget
      // either (the old per-glyph fade path, kept as a regression guard in
      // case a future change reintroduces it).
      final opacityWidgets = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .toList(growable: false);
      for (final opacity in opacityWidgets) {
        expect(
          opacity.opacity,
          1.0,
          reason:
              'a character is still rendering below full opacity '
              'after the streaming animation completed',
        );
      }
    },
  );
}
