import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

void main() {
  testWidgets('StreamingTextMarkdown basic functionality test',
      (WidgetTester tester) async {
    // Build our widget and trigger a frame
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreamingTextMarkdown(
            text: '# Initial Text\n\n**Bold Text**',
            initialText: '# Initial Text',
          ),
        ),
      ),
    );

    // Verify initial text is displayed
    expect(find.text('Initial Text'), findsOneWidget);

    // Wait for animation
    await tester.pump(const Duration(seconds: 1));

    // Verify the new text is displayed
    expect(find.text('Bold Text'), findsOneWidget);
  });

  testWidgets('StreamingTextMarkdown RTL support test',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreamingTextMarkdown(
            text: '# مرحباً\n\nنص عربي',
            initialText: '# مرحباً',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
          ),
        ),
      ),
    );

    expect(find.text('مرحباً'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('نص عربي'), findsOneWidget);
  });

  testWidgets('StreamingTextMarkdown animation settings test',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreamingTextMarkdown(
            text: '# Test\n\nAnimated Text',
            initialText: '# Test',
            fadeInEnabled: true,
            fadeInDuration: const Duration(milliseconds: 300),
            wordByWord: true,
            typingSpeed: const Duration(milliseconds: 50),
          ),
        ),
      ),
    );

    expect(find.text('Test'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Animated Text'), findsOneWidget);
  });
}
