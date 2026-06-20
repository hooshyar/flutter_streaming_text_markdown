import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

/// Returns the longest non-null `Text.data` currently in the tree — robust to
/// incidental empty Text widgets the framework may insert.
String _shown(WidgetTester tester) {
  var best = '';
  for (final t in tester.widgetList<Text>(find.byType(Text))) {
    final data = t.data ?? '';
    if (data.length > best.length) best = data;
  }
  return best;
}

void main() {
  group('Stream typewriter (v1.10.0)', () {
    testWidgets('stream content reveals progressively at typingSpeed, not all at once',
        (tester) async {
      final controller = StreamController<String>();

      await tester.pumpWidget(
        MaterialApp(
          home: StreamingText(
            text: '',
            stream: controller.stream,
            markdownEnabled: false,
            fadeInEnabled: false,
            typingSpeed: const Duration(milliseconds: 50),
          ),
        ),
      );

      controller.add('Hello World');
      await tester.pump(); // immediate first-unit reveal
      await tester.pump(const Duration(milliseconds: 150));

      final partial = _shown(tester);
      expect(partial.isNotEmpty, isTrue,
          reason: 'something should be revealed quickly');
      expect(partial.length, lessThan('Hello World'.length),
          reason: 'chunks must NOT appear all at once — they animate');
      expect('Hello World'.startsWith(partial), isTrue);

      // Let the reveal catch up, then close.
      await tester.pump(const Duration(milliseconds: 2000));
      await controller.close();
      await tester.pump(const Duration(milliseconds: 100));

      expect(_shown(tester), 'Hello World');
    });

    testWidgets('tapping mid-stream reveals received text WITHOUT wiping it',
        (tester) async {
      final controller = StreamController<String>();

      await tester.pumpWidget(
        MaterialApp(
          home: StreamingText(
            text: '', // initial buffer is empty for streams
            stream: controller.stream,
            markdownEnabled: false,
            fadeInEnabled: false,
            typingSpeed: const Duration(milliseconds: 200), // slow → mid-reveal
          ),
        ),
      );

      controller.add('Hello World');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100)); // only ~1 unit shown

      await tester.tap(find.byType(StreamingText));
      await tester.pump();

      expect(_shown(tester), 'Hello World',
          reason:
              'tap-to-complete must surface received text, not reset to the '
              'empty initial text and wipe the stream');

      await controller.close();
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('swapping the stream cancels the old one and shows new content',
        (tester) async {
      final a = StreamController<String>();
      final b = StreamController<String>();

      Widget build(Stream<String> s) => MaterialApp(
            home: StreamingText(
              text: '',
              stream: s,
              markdownEnabled: false,
              animationsEnabled: false, // instant reveal for determinism
            ),
          );

      await tester.pumpWidget(build(a.stream));
      a.add('from A');
      await tester.pump();
      expect(_shown(tester), 'from A');

      await tester.pumpWidget(build(b.stream));
      await tester.pump();

      b.add('from B');
      await tester.pump();
      a.add('A should be ignored now');
      await tester.pump();

      final shown = _shown(tester);
      expect(shown, contains('from B'));
      expect(shown, isNot(contains('from A')));

      await a.close();
      await b.close();
    });

    testWidgets('controller progress advances during stream and reaches 1.0 on done',
        (tester) async {
      final controller = StreamController<String>();
      final stc = StreamingTextController();
      double last = 0;
      stc.onProgressChanged((p) => last = p);

      await tester.pumpWidget(
        MaterialApp(
          home: StreamingText(
            text: '',
            stream: controller.stream,
            controller: stc,
            markdownEnabled: false,
            fadeInEnabled: false,
            typingSpeed: const Duration(milliseconds: 20),
          ),
        ),
      );

      controller.add('abcdefghij'); // 10 graphemes
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(last, greaterThan(0.0));
      expect(last, lessThan(1.0),
          reason: 'progress must not hit 100% while still streaming');

      await tester.pump(const Duration(milliseconds: 300));
      await controller.close();
      await tester.pump(const Duration(milliseconds: 50));

      expect(stc.progress, 1.0);
      stc.dispose();
    });

    testWidgets('animationsEnabled:false reveals stream chunks instantly',
        (tester) async {
      final controller = StreamController<String>();

      await tester.pumpWidget(
        MaterialApp(
          home: StreamingText(
            text: '',
            stream: controller.stream,
            markdownEnabled: false,
            animationsEnabled: false,
          ),
        ),
      );

      controller.add('instant chunk');
      await tester.pump();
      expect(_shown(tester), 'instant chunk');

      await controller.close();
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
