import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart' show MarkdownComponent;

import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

void main() {
  group('StreamingTextMarkdown', () {
    testWidgets('renders initial text correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StreamingTextMarkdown(
            text: '# Hello\nWorld',
            initialText: '# Hello',
            markdownEnabled: true,
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(StreamingTextMarkdown), findsOneWidget);
      expect(find.byType(StreamingText), findsOneWidget);
    });

    testWidgets('supports markdown formatting', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StreamingTextMarkdown(
            text: '**Bold** and *italic*',
            markdownEnabled: true,
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(StreamingTextMarkdown), findsOneWidget);
      expect(find.byType(StreamingText), findsOneWidget);
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

    testWidgets('handles text with emoji (grapheme clusters)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StreamingText(
            text: 'Great 👍 Keep going',
            typingSpeed: Duration(milliseconds: 10),
            markdownEnabled: false,
          ),
        ),
      );

      // Let animation run
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(StreamingText), findsOneWidget);
    });
  });

  group('Custom builders', () {
    testWidgets('accepts imageBuilder parameter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StreamingTextMarkdown(
            text: '![alt](https://example.com/image.png)',
            markdownEnabled: true,
            imageBuilder: (context, url) => const Icon(Icons.image),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(StreamingTextMarkdown), findsOneWidget);
    });

    testWidgets('accepts onLinkTap callback', (tester) async {
      String? tappedUrl;
      await tester.pumpWidget(
        MaterialApp(
          home: StreamingTextMarkdown(
            text: '[link](https://example.com)',
            markdownEnabled: true,
            onLinkTap: (url, title) {
              tappedUrl = url;
            },
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(StreamingTextMarkdown), findsOneWidget);
    });

    testWidgets('accepts components and inlineComponents parameters',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StreamingTextMarkdown(
            text: '# Header\n**bold** *italic*',
            markdownEnabled: true,
            components: const <MarkdownComponent>[],
            inlineComponents: const <MarkdownComponent>[],
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(StreamingTextMarkdown), findsOneWidget);
    });

    testWidgets('accepts codeBuilder parameter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StreamingTextMarkdown(
            text: '```dart\nprint("hello");\n```',
            markdownEnabled: true,
            codeBuilder: (context, name, code, closed) => Text('Code: $code'),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(StreamingTextMarkdown), findsOneWidget);
    });
  });

  group('Trailing fade', () {
    testWidgets('trailingFadeEnabled defaults to false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StreamingTextMarkdown(
            text: 'Hello world',
            markdownEnabled: true,
          ),
        ),
      );

      await tester.pump();
      final widget = tester.widget<StreamingTextMarkdown>(
        find.byType(StreamingTextMarkdown),
      );
      expect(widget.trailingFadeEnabled, false);
    });

    testWidgets('trailingFadeEnabled can be set to true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StreamingTextMarkdown(
            text: '## Hello\n\nStreaming text with trailing fade.',
            markdownEnabled: true,
            trailingFadeEnabled: true,
            typingSpeed: Duration(milliseconds: 20),
          ),
        ),
      );

      await tester.pump();
      final widget = tester.widget<StreamingTextMarkdown>(
        find.byType(StreamingTextMarkdown),
      );
      expect(widget.trailingFadeEnabled, true);

      // Let animation run and complete without errors
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(StreamingTextMarkdown), findsOneWidget);
    });

    testWidgets('named constructors default trailingFadeEnabled to false',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StreamingTextMarkdown.claude(
            text: 'Test text',
          ),
        ),
      );

      await tester.pump();
      final widget = tester.widget<StreamingTextMarkdown>(
        find.byType(StreamingTextMarkdown),
      );
      expect(widget.trailingFadeEnabled, false);
    });

    testWidgets(
        'completes typing exactly once with trailingFadeEnabled (regression: #12)',
        (tester) async {
      var completed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StreamingTextMarkdown(
            text: 'short',
            markdownEnabled: true,
            trailingFadeEnabled: true,
            typingSpeed: const Duration(milliseconds: 5),
            fadeInDuration: const Duration(milliseconds: 50),
            onComplete: () => completed++,
          ),
        ),
      );

      // Pump past typing animation and fade-out window
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(completed, 1, reason: 'onComplete must fire exactly once');
    });

    testWidgets(
        'completes stream exactly once with trailingFadeEnabled (regression: #12)',
        (tester) async {
      final controller = StreamController<String>();
      var completed = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StreamingText(
            text: '',
            stream: controller.stream,
            markdownEnabled: true,
            trailingFadeEnabled: true,
            fadeInDuration: const Duration(milliseconds: 50),
            onComplete: () => completed++,
          ),
        ),
      );

      controller.add('hello');
      await tester.pump(const Duration(milliseconds: 100));
      await controller.close();
      // Pump past async stream-done dispatch and fade-out
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(completed, 1,
          reason: 'onComplete must fire exactly once on stream done');
    });
  });

  group('StreamingTextMarkdown stream: parameter (v1.9.0)', () {
    // Mirrors the proven v1.7 trailing-fade regression test setup,
    // but on the outer StreamingTextMarkdown widget instead of the
    // inner StreamingText.
    testWidgets('completes onComplete once when stream closes', (tester) async {
      final controller = StreamController<String>();
      var completed = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StreamingTextMarkdown(
            text: '',
            stream: controller.stream,
            markdownEnabled: true,
            trailingFadeEnabled: true,
            fadeInDuration: const Duration(milliseconds: 50),
            onComplete: () => completed++,
          ),
        ),
      );

      controller.add('hello');
      await tester.pump(const Duration(milliseconds: 100));
      await controller.close();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(completed, 1,
          reason: 'onComplete must fire exactly once on stream done');
    });

    testWidgets('text-only usage still works (backward compat)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StreamingTextMarkdown(
            text: 'static content',
            animationsEnabled: false,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('static content'), findsOneWidget);
    });

    testWidgets('preset constructors (.chatGPT) accept stream parameter',
        (tester) async {
      final controller = StreamController<String>();
      var completed = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StreamingTextMarkdown.chatGPT(
            stream: controller.stream,
            onComplete: () => completed++,
          ),
        ),
      );

      controller.add('hi');
      await tester.pump(const Duration(milliseconds: 100));
      await controller.close();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(completed, 1);
    });
  });

  group('completeAnimationOnTap', () {
    testWidgets('tap jumps animation to completion by default', (tester) async {
      var completed = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StreamingTextMarkdown(
            text: 'hello world this should take a while to type out',
            typingSpeed: const Duration(milliseconds: 50),
            fadeInEnabled: false,
            onComplete: () => completed++,
          ),
        ),
      );

      // Let a couple of characters in, but nowhere near completion.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(completed, 0, reason: 'animation should still be running');

      await tester.tap(find.byType(StreamingText));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(completed, 1,
          reason: 'tap should short-circuit the animation and fire onComplete');
    });

    testWidgets(
        'completeAnimationOnTap: false lets taps pass through without completing',
        (tester) async {
      var completed = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StreamingTextMarkdown(
            text: 'hello world this should take a while to type out',
            typingSpeed: const Duration(milliseconds: 50),
            fadeInEnabled: false,
            completeAnimationOnTap: false,
            onComplete: () => completed++,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(completed, 0);

      await tester.tap(find.byType(StreamingText));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(completed, 0, reason: 'tap must not short-circuit the animation');

      // Let the animation finish naturally; onComplete should still fire once.
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(completed, 1,
          reason:
              'natural completion should still fire onComplete exactly once');
    });
  });
}
