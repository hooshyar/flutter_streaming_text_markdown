// B2-S3 additive StreamingTextController accessors: `isStreaming` (an open
// stream or an ongoing reveal), `markdown` (the full source text, for
// copy), `copyToClipboard()`, and ChangeNotifier multi-listener support.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

void main() {
  group('detached controller', () {
    test('reports not streaming and empty markdown', () {
      final controller = StreamingTextController();
      addTearDown(controller.dispose);

      expect(controller.isStreaming, isFalse);
      expect(controller.markdown, '');
    });

    test('supports multiple listeners (ChangeNotifier)', () {
      final controller = StreamingTextController();
      addTearDown(controller.dispose);

      var first = 0;
      var second = 0;
      controller.addListener(() => first++);
      controller.addListener(() => second++);

      controller.restart();

      expect(first, greaterThan(0));
      expect(second, first);
    });
  });

  group('static text', () {
    testWidgets(
      'isStreaming/markdown across start, pause, resume, skip and complete',
      (tester) async {
        final controller = StreamingTextController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamingText(
                revealMode: null,
                text: 'Hello World',
                markdownEnabled: false,
                typingSpeed: const Duration(milliseconds: 20),
                controller: controller,
              ),
            ),
          ),
        );
        await tester.pump();

        // Attach -> reveal running.
        expect(controller.isStreaming, isTrue);
        expect(controller.markdown, 'Hello World');

        controller.pause();
        await tester.pump();
        expect(
          controller.isStreaming,
          isTrue,
          reason: 'a paused reveal is still an ongoing reveal',
        );
        expect(controller.markdown, 'Hello World');

        controller.resume();
        await tester.pump(const Duration(milliseconds: 20));
        expect(controller.isStreaming, isTrue);

        controller.skipToEnd();
        await tester.pump();
        expect(controller.isCompleted, isTrue);
        expect(controller.isStreaming, isFalse);
        expect(
          controller.markdown,
          'Hello World',
          reason: 'the source stays readable after completion',
        );

        // A new revealing cycle streams again, then settles.
        controller.restart();
        await tester.pump();
        expect(controller.isStreaming, isTrue);
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(controller.isCompleted, isTrue);
        expect(controller.isStreaming, isFalse);
        expect(controller.markdown, 'Hello World');
      },
    );

    testWidgets('markdown tracks a swapped-in static text', (tester) async {
      final controller = StreamingTextController();
      addTearDown(controller.dispose);

      Widget build(String text) {
        return MaterialApp(
          home: Scaffold(
            body: StreamingText(
              revealMode: null,
              text: text,
              markdownEnabled: false,
              animationsEnabled: false,
              controller: controller,
            ),
          ),
        );
      }

      await tester.pumpWidget(build('Alpha'));
      await tester.pump();
      expect(controller.markdown, 'Alpha');
      expect(
        controller.isStreaming,
        isFalse,
        reason: 'instant reveal of a closed source completes immediately',
      );

      await tester.pumpWidget(build('Beta'));
      await tester.pump();
      expect(controller.markdown, 'Beta');
      expect(controller.isStreaming, isFalse);
    });
  });

  group('stream', () {
    testWidgets(
      'isStreaming stays true while the stream is open, markdown grows '
      'with chunks',
      (tester) async {
        final stream = StreamController<String>();
        addTearDown(() {
          if (!stream.isClosed) stream.close();
        });
        final controller = StreamingTextController();
        addTearDown(controller.dispose);

        var notifications = 0;
        controller.addListener(() => notifications++);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamingText(
                revealMode: null,
                text: '',
                stream: stream.stream,
                markdownEnabled: false,
                typingSpeed: const Duration(milliseconds: 10),
                controller: controller,
              ),
            ),
          ),
        );
        await tester.pump();

        // Open stream with nothing received yet: already streaming.
        expect(controller.isStreaming, isTrue);
        expect(controller.markdown, '');

        stream.add('Hello');
        await tester.pump();
        await tester.pump();
        expect(controller.markdown, 'Hello');
        expect(
          controller.isStreaming,
          isTrue,
          reason: 'stream is still open even if the reveal catches up',
        );

        controller.pause();
        await tester.pump();
        expect(controller.isStreaming, isTrue);
        controller.resume();
        await tester.pump();

        stream.add(' World');
        await tester.pump();
        await tester.pump();
        expect(controller.markdown, 'Hello World');
        expect(controller.isStreaming, isTrue);

        final beforeClose = notifications;
        await stream.close();
        await tester.pump();
        expect(
          notifications,
          greaterThan(beforeClose),
          reason: 'the input-open flip notifies listeners',
        );

        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(controller.isCompleted, isTrue);
        expect(controller.isStreaming, isFalse);
        expect(controller.markdown, 'Hello World');
      },
    );
  });

  group('copyToClipboard', () {
    testWidgets('writes the full source to the clipboard', (tester) async {
      final controller = StreamingTextController();
      addTearDown(controller.dispose);

      Map<dynamic, dynamic>? clipboardData;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardData = call.arguments as Map<dynamic, dynamic>;
          }
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingText(
              revealMode: null,
              text: 'Copy **me**',
              markdownEnabled: false,
              typingSpeed: const Duration(milliseconds: 10),
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pump();

      await controller.copyToClipboard();
      expect(clipboardData, isNotNull);
      expect(clipboardData!['text'], 'Copy **me**');
    });
  });
}
