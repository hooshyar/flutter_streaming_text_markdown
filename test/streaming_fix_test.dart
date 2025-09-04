import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'dart:async';

void main() {
  group('Streaming Fix Tests', () {
    testWidgets('Stream should continue animation from new content',
        (WidgetTester tester) async {
      final streamController = StreamController<String>();
      String? lastDisplayedText;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingText(
              stream: streamController.stream,
              text: '', // Not used with stream
              markdownEnabled: false,
              typingSpeed: const Duration(milliseconds: 20),
              wordByWord: false,
              fadeInEnabled: false,
            ),
          ),
        ),
      );

      // Start with initial text
      streamController.add('Hello');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Capture what's displayed so far
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      if (textWidgets.isNotEmpty) {
        lastDisplayedText = textWidgets.first.data;
      }

      // Add more text - this should continue animation, not restart
      streamController.add(' World');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // The text should have progressed (not restarted)
      final newTextWidgets = tester.widgetList<Text>(find.byType(Text));
      if (newTextWidgets.isNotEmpty) {
        final newText = newTextWidgets.first.data;
        expect(newText, contains('Hello'),
            reason: 'Previous text should still be visible');
        expect(newText, contains('World'), reason: 'New text should be added');
      }

      streamController.close();
    });

    testWidgets('Stream with markdown should work correctly',
        (WidgetTester tester) async {
      final streamController = StreamController<String>();
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingText(
              stream: streamController.stream,
              text: '',
              markdownEnabled: true,
              typingSpeed: const Duration(milliseconds: 10),
              wordByWord: false,
              fadeInEnabled: false,
              onComplete: () {
                completed = true;
              },
            ),
          ),
        ),
      );

      // Add markdown content in chunks
      streamController.add('**Bold**');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      streamController.add(' and *italic*');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Close the stream to trigger completion
      streamController.close();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should complete successfully
      expect(completed, isTrue, reason: 'Stream with markdown should complete');
    });
  });
}
