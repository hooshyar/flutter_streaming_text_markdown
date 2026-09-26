// Stream-mode lifecycle for the S5 engine rewire: instant + stream (W26,
// W23), config changes mid-stream never re-listening (W9), controller
// pause/stop/restart in stream mode (W15), and stream errors (W16). Each of
// these fails on main (38bc831) and passes after the rewrite.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

// While revealing, showCursor defaults to true and the widget renders a
// `Text.rich` with a caret WidgetSpan instead of a plain `Text.data`. Read
// content-only plain text (excluding the caret placeholder) so these
// assertions are about text content, not the caret.
String _displayed(WidgetTester tester) {
  final texts = tester.widgetList<Text>(find.byType(Text));
  return texts
      .map((t) =>
          t.textSpan?.toPlainText(includePlaceholders: false) ?? t.data ?? '')
      .join();
}

void main() {
  testWidgets(
    'instant(stream:) shows chunks as they arrive and completes once on '
    'close (W26, W23)',
    (tester) async {
      final controller = StreamController<String>();
      addTearDown(() {
        if (!controller.isClosed) controller.close();
      });
      var completeCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: '',
              stream: controller.stream,
              animationsEnabled: false,
              markdownEnabled: false,
              onComplete: () => completeCount++,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_displayed(tester), isEmpty);

      controller.add('Hello');
      await tester.pump();
      await tester.pump();
      expect(
        _displayed(tester),
        'Hello',
        reason: 'instant + stream must show chunks immediately (W26)',
      );
      expect(completeCount, 0);

      controller.add(' World');
      await tester.pump();
      await tester.pump();
      expect(_displayed(tester), 'Hello World');
      expect(
        completeCount,
        0,
        reason: 'must not complete on every update while open (W23)',
      );

      await controller.close();
      await tester.pump();
      await tester.pump();
      expect(completeCount, 1);
    },
  );

  testWidgets('config change mid-stream never throws or re-listens (W9)', (
    tester,
  ) async {
    final controller = StreamController<String>();
    addTearDown(() {
      if (!controller.isClosed) controller.close();
    });

    // `controller.stream` is read fresh on every build below - NOT cached
    // in a local/field - because `StreamController.stream` returns a new
    // wrapper object on every access (`identical` is always false, even
    // though it's `==`-equal to any other access on the same controller).
    // A caller doing exactly this (very common in real apps - `stream:
    // myController.stream` written straight in `build()`) must not have
    // that look like a genuine stream identity swap on every rebuild: a
    // single-subscription stream can only ever be listened to once, so a
    // false swap would throw "Stream has already been listened to".
    Widget build({required bool markdownEnabled, required bool wordByWord}) {
      return MaterialApp(
        home: Scaffold(
          body: StreamingText(
            text: '',
            stream: controller.stream,
            markdownEnabled: markdownEnabled,
            wordByWord: wordByWord,
            typingSpeed: const Duration(milliseconds: 5),
          ),
        ),
      );
    }

    await tester.pumpWidget(build(markdownEnabled: false, wordByWord: false));
    controller.add('Hello there');
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    // Changing markdownEnabled/wordByWord mid-stream must not throw the old
    // "Stream has already been listened to" StateError.
    await tester.pumpWidget(build(markdownEnabled: true, wordByWord: true));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.takeException(), isNull);

    // A plain rebuild with no config change at all: `controller.stream` is
    // still a fresh object each time, so this must not re-listen either.
    await tester.pumpWidget(build(markdownEnabled: true, wordByWord: true));
    expect(tester.takeException(), isNull);

    controller.add(' more');
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('Hello', findRichText: true),
      findsOneWidget,
    );

    await controller.close();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('Hello there more', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets(
    'a stream read fresh in build() on StreamingTextMarkdown never '
    're-listens on a config change or a plain rebuild (W9)',
    (tester) async {
      final controller = StreamController<String>();
      addTearDown(() {
        if (!controller.isClosed) controller.close();
      });

      Widget build({required bool markdownEnabled, required int typingMs}) {
        return MaterialApp(
          home: Scaffold(
            body: StreamingTextMarkdown(
              stream: controller.stream,
              markdownEnabled: markdownEnabled,
              typingSpeed: Duration(milliseconds: typingMs),
            ),
          ),
        );
      }

      await tester.pumpWidget(build(markdownEnabled: false, typingMs: 5));
      controller.add('Hello there');
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      // Config change mid-stream (markdownEnabled + typingSpeed).
      await tester.pumpWidget(build(markdownEnabled: true, typingMs: 20));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.takeException(), isNull);

      // Plain rebuild, no config change.
      await tester.pumpWidget(build(markdownEnabled: true, typingMs: 20));
      expect(tester.takeException(), isNull);

      controller.add(' more');
      await tester.pump();
      expect(tester.takeException(), isNull);

      await controller.close();
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Hello there', findRichText: true),
          findsOneWidget);
    },
  );

  testWidgets('pause holds, stop empties and goes idle, restart replays (W15)', (
    tester,
  ) async {
    final controller = StreamController<String>();
    addTearDown(() {
      if (!controller.isClosed) controller.close();
    });
    final streamCtrl = StreamingTextController();
    addTearDown(streamCtrl.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreamingText(
            text: '',
            stream: controller.stream,
            markdownEnabled: false,
            typingSpeed: const Duration(milliseconds: 10),
            controller: streamCtrl,
          ),
        ),
      ),
    );
    controller.add('ABCDEFGHIJ');
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    final beforePause = _displayed(tester);
    expect(beforePause.isNotEmpty, isTrue);

    streamCtrl.pause();
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(_displayed(tester), beforePause, reason: 'pause holds in stream mode');

    streamCtrl.resume();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(
      _displayed(tester).length,
      greaterThan(beforePause.length),
      reason: 'resume continues revealing in stream mode',
    );

    streamCtrl.stop();
    await tester.pump();
    expect(_displayed(tester), isEmpty, reason: 'stop empties the reveal');

    streamCtrl.restart();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    // Restart replays everything received so far. The stream is still
    // open, so the final grapheme stays withheld (it might still extend).
    expect(
      _displayed(tester),
      'ABCDEFGHI',
      reason: 'restart replays received content in stream mode',
    );
  });

  testWidgets(
    'a stream error sets the error state, keeps revealed text, and uses '
    'errorBuilder (W16)',
    (tester) async {
      final controller = StreamController<String>();
      addTearDown(() {
        if (!controller.isClosed) controller.close();
      });
      final streamCtrl = StreamingTextController();
      addTearDown(streamCtrl.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: '',
              stream: controller.stream,
              markdownEnabled: false,
              animationsEnabled: false,
              controller: streamCtrl,
              errorBuilder: (context, error) => Text('custom-error: $error'),
            ),
          ),
        ),
      );
      controller.add('partial');
      await tester.pump();
      await tester.pump();
      expect(_displayed(tester), 'partial');

      controller.addError(StateError('boom'));
      await tester.pump();
      await tester.pump();

      expect(streamCtrl.state, StreamingTextState.error);
      expect(streamCtrl.error, isA<StateError>());
      expect(find.textContaining('custom-error:'), findsOneWidget);
    },
  );

  testWidgets(
    'without an errorBuilder, the default view keeps revealed text plus an '
    'Error line (W16)',
    (tester) async {
      final controller = StreamController<String>();
      addTearDown(() {
        if (!controller.isClosed) controller.close();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: '',
              stream: controller.stream,
              markdownEnabled: false,
              animationsEnabled: false,
            ),
          ),
        ),
      );
      controller.add('partial');
      await tester.pump();
      await tester.pump();

      controller.addError(StateError('boom'));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('partial'), findsOneWidget);
      expect(find.textContaining('Error:'), findsOneWidget);
    },
  );
}
