import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

void main() {
  group('Demo App Fix Verification', () {
    testWidgets('ValueKey should not change when text changes',
        (WidgetTester tester) async {
      // This test verifies that the fix we applied to the demo app works correctly
      String text = 'hello ';
      int updateCounter = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          text = text + text; // Append text like demo app does
                          updateCounter++; // This should NOT be in the key
                        });
                      },
                      child: const Text('Append Text'),
                    ),
                    StreamingTextMarkdown.chatGPT(
                      key: const ValueKey(
                          'demo_test'), // Fixed key - no updateCounter
                      text: text,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Get the initial widget
      await tester.pump();
      final initialWidget =
          tester.widget<StreamingText>(find.byType(StreamingText));
      final initialKey = initialWidget.key;

      // Update text (append)
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Get the widget after update
      final updatedWidget =
          tester.widget<StreamingText>(find.byType(StreamingText));
      final updatedKey = updatedWidget.key;

      // The key should be the same - widget should not be recreated
      expect(initialKey, equals(updatedKey),
          reason:
              'Widget key should remain the same to preserve animation state');

      // Verify text was actually updated
      expect(updatedWidget.text, equals('hello hello '),
          reason: 'Text should be appended correctly');
    });

    testWidgets(
        'Bad ValueKey pattern would cause StreamingTextMarkdown recreation (negative test)',
        (WidgetTester tester) async {
      // This test demonstrates the problematic pattern that was in the demo
      String text = 'hello ';
      int updateCounter = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          text = text + text;
                          updateCounter++;
                        });
                      },
                      child: const Text('Append Text'),
                    ),
                    StreamingTextMarkdown.chatGPT(
                      key: ValueKey(
                          'demo_$updateCounter'), // BAD: includes updateCounter
                      text: text,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Get the initial StreamingTextMarkdown widget
      await tester.pump();
      final initialMarkdownWidget = tester
          .widget<StreamingTextMarkdown>(find.byType(StreamingTextMarkdown));
      final initialMarkdownKey = initialMarkdownWidget.key;

      // Update text (append)
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Get the StreamingTextMarkdown widget after update
      final updatedMarkdownWidget = tester
          .widget<StreamingTextMarkdown>(find.byType(StreamingTextMarkdown));
      final updatedMarkdownKey = updatedMarkdownWidget.key;

      // The StreamingTextMarkdown key should be DIFFERENT - this is the bad pattern
      expect(initialMarkdownKey, isNot(equals(updatedMarkdownKey)),
          reason:
              'BAD pattern: StreamingTextMarkdown key changes and causes widget recreation');

      // Verify the keys are actually different values
      expect(initialMarkdownKey.toString(), contains('demo_0'));
      expect(updatedMarkdownKey.toString(), contains('demo_1'));

      // However, thanks to our fix, the inner StreamingText should still have a consistent key
      final streamingTextWidget =
          tester.widget<StreamingText>(find.byType(StreamingText));
      // The inner key should be based on configuration, not the text content
      expect(streamingTextWidget.key.toString(), contains('streaming_text_'));
    });
  });
}
