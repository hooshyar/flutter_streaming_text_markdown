import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'dart:async';

void main() {
  group('Issue Reproduction Tests', () {
    // Test for Issue #3: Markdown and animation conflict
    testWidgets('Issue #3: Markdown enabled should still show animation',
        (WidgetTester tester) async {
      const testText = '**Bold Text** and *italic text*';
      bool animationCompleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: testText,
              markdownEnabled: true, // Markdown is enabled
              typingSpeed: const Duration(milliseconds: 5), // Fast for testing
              wordByWord: false,
              fadeInEnabled: false, // Disable fade-in to simplify
              onComplete: () {
                animationCompleted = true;
              },
            ),
          ),
        ),
      );

      // Initial state should be empty or minimal
      await tester.pump();

      // Let animation run for a reasonable time
      await tester.pump(const Duration(milliseconds: 500));

      // Text should be visible
      final textFinder = find.byType(Text);
      expect(textFinder, findsWidgets);

      // Animation should complete
      expect(animationCompleted, isTrue,
          reason: 'Markdown animation should complete successfully');
    });

    // Test for Issue #1: Animation restart bug with streaming
    testWidgets('Issue #1: New text should animate only new content',
        (WidgetTester tester) async {
      final streamController = StreamController<String>();
      String displayedText = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamBuilder<String>(
              stream: streamController.stream,
              initialData: 'Hello',
              builder: (context, snapshot) {
                displayedText = snapshot.data ?? '';
                return StreamingText(
                  text: displayedText,
                  typingSpeed: const Duration(milliseconds: 10),
                  wordByWord: false,
                );
              },
            ),
          ),
        ),
      );

      // Initial text should be "Hello"
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Add new text
      streamController.add('Hello World');
      await tester.pump();

      // The animation should continue from "Hello" and only animate " World"
      // Not restart from the beginning
      await tester.pump(const Duration(milliseconds: 50));

      // Check that text is being displayed progressively
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      expect(textWidgets.isNotEmpty, isTrue);

      streamController.close();
    });

    // Test for markdown rendering with animation
    testWidgets('Markdown should render while animating',
        (WidgetTester tester) async {
      const testText = '# Header\n**Bold** and *italic*';
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingTextMarkdown(
              text: testText,
              markdownEnabled: true,
              typingSpeed: const Duration(milliseconds: 5),
              fadeInEnabled: false,
              onComplete: () {
                completed = true;
              },
            ),
          ),
        ),
      );

      await tester.pump();

      // Let animation progress
      await tester.pump(const Duration(milliseconds: 300));

      // Should find text widgets being rendered
      expect(find.byType(Text), findsWidgets);

      // Should complete
      expect(completed, isTrue,
          reason: 'StreamingTextMarkdown should complete animation');
    });

    // Test for LaTeX integration (Issue #2 - already addressed)
    testWidgets('LaTeX expressions should render correctly',
        (WidgetTester tester) async {
      const testText = r'The equation $E = mc^2$ is famous';
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: testText,
              latexEnabled: true,
              markdownEnabled: true,
              typingSpeed: const Duration(milliseconds: 5),
              fadeInEnabled: false,
              onComplete: () {
                completed = true;
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // LaTeX should be rendered (as styled text in the current implementation)
      expect(find.byType(Text), findsWidgets);
      expect(completed, isTrue, reason: 'LaTeX animation should complete');
    });
  });
}
