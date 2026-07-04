import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

/// Returns the text currently rendered by the (non-markdown) StreamingText.
String _displayed(WidgetTester tester) {
  final texts = tester.widgetList<Text>(find.byType(Text));
  // The widget renders its content in a single Text when markdownEnabled:false
  // and not animating fade-in. Concatenate defensively in case of splits.
  return texts.map((t) => t.data ?? '').join();
}

void main() {
  group('v1.9.1 slice 1 — cursor ticker', () {
    testWidgets('no repeating ticker after animation completes',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StreamingText(
            text: 'Hello World',
            typingSpeed: Duration(milliseconds: 10),
            markdownEnabled: false,
          ),
        ),
      );

      // showCursor defaults to true — this exercises the default config.
      await tester.pump();
      // "Hello World" is 11 characters; give it plenty of time to finish
      // typing with a margin of pumps.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      // If a ticker (e.g. the cursor AnimationController) is still
      // repeating, pumpAndSettle throws a FlutterError ("did not settle")
      // instead of returning — so simply completing here is the assertion.
      await tester.pumpAndSettle();

      expect(find.byType(StreamingText), findsOneWidget);
    });

    testWidgets('pumpAndSettle completes with showCursor explicitly true',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StreamingText(
            text: 'Test',
            typingSpeed: Duration(milliseconds: 5),
            showCursor: true,
            cursorColor: Colors.red,
            markdownEnabled: false,
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(StreamingText), findsOneWidget);
    });
  });

  group('v1.9.1 slice 2 — streamed chunks animate per typing settings', () {
    testWidgets('stream chunk animates per typingSpeed', (tester) async {
      final controller = StreamController<String>();
      // Guard the teardown close: several tests close the stream in the body to
      // assert post-completion behavior. Closing a broadcast-piped controller
      // twice throws "Cannot close sink while adding stream" and hangs test
      // finalization, so only close here if the body did not already.
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
              fadeInEnabled: false,
              wordByWord: false,
              chunkSize: 1,
              typingSpeed: const Duration(milliseconds: 50),
            ),
          ),
        ),
      );

      const chunk = 'ABCDEFGHIJKLMNOP'; // 16 chars
      controller.add(chunk);
      // Two pumps for the asBroadcastStream microtask hop + first frame.
      await tester.pump();
      await tester.pump();

      // After a single ~60ms tick, only PART of the chunk is visible — it must
      // NOT render instantly (that was the bug this slice fixes).
      await tester.pump(const Duration(milliseconds: 60));
      final partial = _displayed(tester);
      expect(partial.length, greaterThan(0),
          reason: 'some of the chunk should be revealed');
      expect(partial.length, lessThan(chunk.length),
          reason: 'the whole chunk must NOT appear in one frame');

      // After cumulative pump time >= 16 * 50ms, all 16 chars are visible.
      for (var i = 0; i < 18; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(_displayed(tester), equals(chunk));
    });

    testWidgets('wordByWord holds back partial word across chunk boundary',
        (tester) async {
      final controller = StreamController<String>();
      // Guard the teardown close: several tests close the stream in the body to
      // assert post-completion behavior. Closing a broadcast-piped controller
      // twice throws "Cannot close sink while adding stream" and hangs test
      // finalization, so only close here if the body did not already.
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
              fadeInEnabled: false,
              wordByWord: true,
              typingSpeed: const Duration(milliseconds: 30),
            ),
          ),
        ),
      );

      // First chunk ends mid-word ('wor'). The partial word must never render
      // truncated before its whitespace arrives.
      controller.add('Hello wor');
      await tester.pump();
      await tester.pump();

      // Drain generously — 'Hello ' can appear, but 'wor'/'world' must not
      // show truncated while only 'Hello wor' has been received.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        final shown = _displayed(tester);
        // Never a truncated trailing partial word mid-stream.
        expect(shown == 'Hello ' || shown == 'Hello' || shown.isEmpty, isTrue,
            reason: 'partial word held back until whitespace; got: "$shown"');
      }

      // Second chunk completes the word and adds more.
      controller.add('ld done');
      await tester.pump();
      await tester.pump();
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }

      // Close so the final trailing word ('done') is flushed.
      await controller.close();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }

      // Final displayed text must byte-match received exactly.
      expect(_displayed(tester), equals('Hello world done'));
    });

    testWidgets(
        'onComplete and markCompleted fire exactly once when stream '
        'closes after catch-up', (tester) async {
      final controller = StreamController<String>();
      // Guard the teardown close: several tests close the stream in the body to
      // assert post-completion behavior. Closing a broadcast-piped controller
      // twice throws "Cannot close sink while adding stream" and hangs test
      // finalization, so only close here if the body did not already.
      addTearDown(() {
        if (!controller.isClosed) controller.close();
      });
      final streamCtrl = StreamingTextController();
      addTearDown(streamCtrl.dispose);

      var onCompleteCount = 0;
      var controllerCompletedCount = 0;
      streamCtrl.onCompleted(() => controllerCompletedCount++);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: '',
              stream: controller.stream,
              controller: streamCtrl,
              markdownEnabled: false,
              fadeInEnabled: false,
              wordByWord: false,
              chunkSize: 1,
              typingSpeed: const Duration(milliseconds: 20),
              onComplete: () => onCompleteCount++,
            ),
          ),
        ),
      );

      controller.add('Hello');
      await tester.pump();
      await tester.pump();
      // Fully drain the chunk.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(_displayed(tester), equals('Hello'));
      // Not complete yet — stream is still open.
      expect(onCompleteCount, 0);

      // Now close after catch-up.
      await controller.close();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(onCompleteCount, 1, reason: 'onComplete fires exactly once');
      expect(controllerCompletedCount, 1,
          reason: 'controller completion fires exactly once');
    });

    testWidgets('onDone before catch-up completes only after drain finishes',
        (tester) async {
      final controller = StreamController<String>();
      // Guard the teardown close: several tests close the stream in the body to
      // assert post-completion behavior. Closing a broadcast-piped controller
      // twice throws "Cannot close sink while adding stream" and hangs test
      // finalization, so only close here if the body did not already.
      addTearDown(() {
        if (!controller.isClosed) controller.close();
      });

      var onCompleteCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: '',
              stream: controller.stream,
              markdownEnabled: false,
              fadeInEnabled: false,
              wordByWord: false,
              chunkSize: 1,
              typingSpeed: const Duration(milliseconds: 50),
              onComplete: () => onCompleteCount++,
            ),
          ),
        ),
      );

      const chunk = 'ABCDEFGHIJ'; // 10 chars
      controller.add(chunk);
      await tester.pump();
      await tester.pump();

      // Reveal only a couple of chars, then close the stream WHILE the drain
      // is still mid-chunk.
      await tester.pump(const Duration(milliseconds: 60));
      final midway = _displayed(tester);
      expect(midway.length, lessThan(chunk.length),
          reason: 'drain should still be mid-chunk');

      await controller.close();
      await tester.pump(); // let onDone microtask land
      await tester.pump();

      // Completion must NOT have fired yet — the drain hasn't caught up.
      expect(onCompleteCount, 0,
          reason: 'completion waits for the drain to finish');
      expect(_displayed(tester).length, lessThan(chunk.length));

      // Pump the remaining time; now it finishes.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(onCompleteCount, 1, reason: 'fires once after drain completes');
      expect(_displayed(tester), equals(chunk));
    });

    testWidgets('controller progress updates in stream mode', (tester) async {
      final controller = StreamController<String>();
      // Guard the teardown close: several tests close the stream in the body to
      // assert post-completion behavior. Closing a broadcast-piped controller
      // twice throws "Cannot close sink while adding stream" and hangs test
      // finalization, so only close here if the body did not already.
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
              controller: streamCtrl,
              markdownEnabled: false,
              fadeInEnabled: false,
              wordByWord: false,
              chunkSize: 1,
              typingSpeed: const Duration(milliseconds: 30),
            ),
          ),
        ),
      );

      // Before anything arrives, progress stays at its default 0.0 (stream
      // mode no longer divides by widget.text.length which is '').
      expect(streamCtrl.progress, 0.0);

      controller.add('ABCDEFGH'); // 8 chars
      await tester.pump();
      await tester.pump();

      // Partway through the drain, progress is strictly between 0 and 1.
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pump(const Duration(milliseconds: 30));
      expect(streamCtrl.progress, greaterThan(0.0));
      expect(streamCtrl.progress, lessThan(1.0));

      // Finish draining + close → progress reaches exactly 1.0.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
      await controller.close();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
      expect(streamCtrl.progress, 1.0);
    });
  });

  group('v1.9.1 slice 3 — tap/skipToEnd catch up instead of erasing', () {
    testWidgets(
        'tap mid-stream catches up to received text without erasing, '
        'does not complete while stream open', (tester) async {
      final controller = StreamController<String>();
      addTearDown(() {
        if (!controller.isClosed) controller.close();
      });

      var onCompleteCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: '',
              stream: controller.stream,
              markdownEnabled: false,
              fadeInEnabled: false,
              wordByWord: false,
              chunkSize: 1,
              typingSpeed: const Duration(milliseconds: 50),
              onComplete: () => onCompleteCount++,
            ),
          ),
        ),
      );

      const chunk = 'ABCDEFGHIJKLMNOP'; // 16 chars
      controller.add(chunk);
      // Two pumps for the asBroadcastStream microtask hop + first frame.
      await tester.pump();
      await tester.pump();

      // Let a little time pass so only part of the chunk has drained.
      await tester.pump(const Duration(milliseconds: 60));
      final midway = _displayed(tester);
      expect(midway.length, greaterThan(0));
      expect(midway.length, lessThan(chunk.length),
          reason: 'drain should still be mid-chunk before the tap');

      // Tap the widget: should catch displayed up to received, NOT erase it,
      // and NOT complete since the stream is still open.
      await tester.tap(find.byType(StreamingText));
      await tester.pump();

      expect(_displayed(tester), equals(chunk),
          reason: 'tap should reveal everything received so far');
      expect(onCompleteCount, 0,
          reason: 'must not complete while the stream is still open');

      // Now close the stream — completion should fire exactly once, since
      // displayed already equals received.
      await controller.close();
      await tester.pump();
      await tester.pump();

      expect(onCompleteCount, 1,
          reason: 'onComplete fires exactly once after stream closes');
    });

    testWidgets('tap mid-stream completes immediately if stream already done',
        (tester) async {
      final controller = StreamController<String>();
      addTearDown(() {
        if (!controller.isClosed) controller.close();
      });

      var onCompleteCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: '',
              stream: controller.stream,
              markdownEnabled: false,
              fadeInEnabled: false,
              wordByWord: false,
              chunkSize: 1,
              typingSpeed: const Duration(milliseconds: 50),
              onComplete: () => onCompleteCount++,
            ),
          ),
        ),
      );

      const chunk = 'ABCDEFGHIJ'; // 10 chars
      controller.add(chunk);
      await tester.pump();
      await tester.pump();

      // Let a couple of characters render before closing, so the widget has
      // non-empty layout (and is hit-testable) at tap time.
      await tester.pump(const Duration(milliseconds: 60));

      // Close the stream while the drain is still mid-chunk.
      await controller.close();
      await tester.pump();
      await tester.pump();

      final midway = _displayed(tester);
      expect(midway.length, greaterThan(0));
      expect(midway.length, lessThan(chunk.length),
          reason: 'drain should still be mid-chunk when we tap');
      expect(onCompleteCount, 0);

      // Tap: stream is already done, so this should catch up AND complete.
      await tester.tap(find.byType(StreamingText));
      await tester.pump();

      expect(_displayed(tester), equals(chunk));
      expect(onCompleteCount, 1,
          reason: 'tap completes immediately since the stream was done');

      // Tapping again must not double-fire onComplete.
      await tester.tap(find.byType(StreamingText));
      await tester.pump();
      expect(onCompleteCount, 1);
    });

    testWidgets(
        'skipToEnd via controller behaves the same as tap in stream mode',
        (tester) async {
      final controller = StreamController<String>();
      addTearDown(() {
        if (!controller.isClosed) controller.close();
      });
      final streamCtrl = StreamingTextController();
      addTearDown(streamCtrl.dispose);

      var onCompleteCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: '',
              stream: controller.stream,
              controller: streamCtrl,
              markdownEnabled: false,
              fadeInEnabled: false,
              wordByWord: false,
              chunkSize: 1,
              typingSpeed: const Duration(milliseconds: 50),
              onComplete: () => onCompleteCount++,
            ),
          ),
        ),
      );

      const chunk = 'ABCDEFGHIJKLMNOP'; // 16 chars
      controller.add(chunk);
      await tester.pump();
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 60));
      final midway = _displayed(tester);
      expect(midway.length, greaterThan(0));
      expect(midway.length, lessThan(chunk.length));

      // Stream still open — skipToEnd should catch up but not complete.
      streamCtrl.skipToEnd();
      await tester.pump();

      expect(_displayed(tester), equals(chunk));
      expect(onCompleteCount, 0,
          reason: 'must not complete while the stream is still open');

      await controller.close();
      await tester.pump();
      await tester.pump();

      expect(onCompleteCount, 1);
    });

    testWidgets('tap in non-stream mode is unchanged (regression guard)',
        (tester) async {
      var onCompleteCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: 'Hello World',
              markdownEnabled: false,
              typingSpeed: const Duration(milliseconds: 50),
              onComplete: () => onCompleteCount++,
            ),
          ),
        ),
      );

      await tester.pump();
      // Let a couple characters render (non-empty layout) before tapping,
      // well before the animation would finish.
      await tester.pump(const Duration(milliseconds: 100));
      expect(onCompleteCount, 0, reason: 'animation should still be running');
      await tester.tap(find.byType(StreamingText));
      await tester.pump();

      expect(_displayed(tester), equals('Hello World'),
          reason: 'tap should jump straight to the full static text');
      expect(onCompleteCount, 1);
    });
  });
}
