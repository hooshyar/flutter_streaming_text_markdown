import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

void main() {
  testWidgets(
    'word-by-word Pause then Resume never redisplays a doubled word',
    (WidgetTester tester) async {
      // Mirrors the demo's Controller section repro (2026-09-03 QA pass):
      // word-by-word mode, pause a few words in, resume, and watch for a
      // frame where the visible text contains a duplicated token like
      // "...being animated animated with...".
      const text = '## Streaming Text Controller\n\n'
          'This text is being animated with a StreamingTextController. '
          'You can pause the animation mid-stream and resume from exactly '
          'where you left off without repeating a word.';
      const typingSpeed = Duration(milliseconds: 10);

      final controller = StreamingTextController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingTextMarkdown(
              text: text,
              wordByWord: true,
              typingSpeed: typingSpeed,
              markdownEnabled: false,
              controller: controller,
            ),
          ),
        ),
      );

      String currentText() =>
          tester.widget<Text>(find.byType(Text).first).data ?? '';

      final duplicateWordPattern = RegExp(r'\b(\w+)\s+\1\b');
      void expectNoDuplicateWord() {
        final displayed = currentText();
        final match = duplicateWordPattern.firstMatch(displayed);
        expect(
          match,
          isNull,
          reason: 'displayed text contains a duplicated word: "$displayed"',
        );
      }

      // Let a handful of words stream in.
      for (var i = 0; i < 5; i++) {
        await tester.pump(typingSpeed);
        expectNoDuplicateWord();
      }

      controller.pause();
      await tester.pump();
      final pausedText = currentText();

      // Paused: nothing should change even as time passes.
      await tester.pump(typingSpeed * 3);
      expect(currentText(), pausedText);

      controller.resume();
      // Check every frame right after resume, since the bug only showed a
      // duplicated word for a single frame.
      for (var i = 0; i < 10; i++) {
        await tester.pump(typingSpeed);
        expectNoDuplicateWord();
      }

      await tester.pumpAndSettle();
      expectNoDuplicateWord();
      // Final text should contain every real word from the source exactly
      // once each (buffer whitespace/newline normalization aside).
      expect(currentText(), contains('StreamingTextController'));
      expect(currentText(), contains('repeating a word'));
    },
  );
}
