import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

void main() {
  group('Simple Fix Tests', () {
    testWidgets('Simple markdown animation should complete', (WidgetTester tester) async {
      bool completed = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: '**Bold** text',
              markdownEnabled: true,
              typingSpeed: const Duration(milliseconds: 5), // Very fast for testing
              wordByWord: false,
              fadeInEnabled: false, // Disable fade-in to simplify
              onComplete: () {
                completed = true;
              },
            ),
          ),
        ),
      );

      // Wait for the widget to mount
      await tester.pump();
      
      // Let it animate for a short time
      await tester.pump(const Duration(milliseconds: 100));
      
      // Since we disabled fade-in and used fast typing, it should complete quickly
      // Wait a bit more and check if it completed
      await tester.pump(const Duration(milliseconds: 500));
      
      // The animation should have completed
      expect(completed, isTrue, reason: 'Animation should complete when markdown is enabled');
    });

    testWidgets('Simple text animation without markdown should complete', (WidgetTester tester) async {
      bool completed = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: 'Simple text',
              markdownEnabled: false,
              typingSpeed: const Duration(milliseconds: 5),
              wordByWord: false,
              fadeInEnabled: false,
              onComplete: () {
                completed = true;
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));
      
      expect(completed, isTrue, reason: 'Simple animation should complete');
    });
    
    testWidgets('Animation state tracking works correctly', (WidgetTester tester) async {
      // This test checks if our state management fixes work
      bool completed = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: '**Test** text',
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

      await tester.pump();
      
      // Let it run
      await tester.pump(const Duration(milliseconds: 300));
      
      // Should complete successfully
      expect(completed, isTrue, reason: 'State management should allow animation to complete');
    });
  });
}