import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

void main() {
  group('StreamingTextMarkdown', () {
    testWidgets('renders initial text correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StreamingTextMarkdown(
            text: '# Hello\nWorld',
            initialText: '# Hello',
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(StreamingTextMarkdown), findsOneWidget);
      expect(find.byType(MarkdownBody), findsOneWidget);
    });

    testWidgets('supports markdown formatting', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StreamingTextMarkdown(
            text: '**Bold** and *italic*',
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(StreamingTextMarkdown), findsOneWidget);
      expect(find.byType(MarkdownBody), findsOneWidget);
    });

    testWidgets('handles RTL text correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StreamingTextMarkdown(
            text: 'مرحبا',
            textDirection: TextDirection.rtl,
          ),
        ),
      );

      await tester.pump();
      final widget = tester.widget<StreamingTextMarkdown>(
        find.byType(StreamingTextMarkdown),
      );
      expect(widget.textDirection, TextDirection.rtl);
    });

    testWidgets('supports word-by-word animation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StreamingTextMarkdown(
            text: 'Hello World',
            wordByWord: true,
            typingSpeed: Duration(milliseconds: 50),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(StreamingTextMarkdown), findsOneWidget);
    });

    testWidgets('supports fade-in animation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StreamingTextMarkdown(
            text: 'Fade In Text',
            fadeInEnabled: true,
            fadeInDuration: Duration(milliseconds: 100),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(StreamingTextMarkdown), findsOneWidget);
    });
  });

  group('StreamingText', () {
    testWidgets('handles stream updates', (tester) async {
      final controller = StreamController<String>();

      await tester.pumpWidget(
        MaterialApp(
          home: StreamingText(
            text: '',
            stream: controller.stream,
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(StreamingText), findsOneWidget);

      controller.add('Hello');
      await tester.pump();
      expect(find.byType(Text), findsOneWidget);

      await controller.close();
    });

    testWidgets('supports custom text style', (tester) async {
      const style = TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.blue,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: StreamingText(
            text: 'Styled Text',
            style: style,
            typingSpeed: Duration.zero,
            markdownEnabled: false,
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(StreamingText), findsOneWidget);
    });
  });
}
