// Controller <-> widget integration for the S5 engine rewire: swapping the
// controller instance rebinds cleanly (W22), onCompleted/onComplete fire
// exactly once including a tap after completion (W3, W25), and a plain-text
// fade over many characters uses a bounded number of transient tickers
// (single-ticker fade, not one AnimationController per glyph).

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

void main() {
  testWidgets('swapping the controller instance rebinds (W22)', (
    tester,
  ) async {
    final controllerA = StreamingTextController();
    addTearDown(controllerA.dispose);
    final controllerB = StreamingTextController();
    addTearDown(controllerB.dispose);

    Widget build(StreamingTextController controller) {
      return MaterialApp(
        home: Scaffold(
          body: StreamingText(
            text: 'Hello World',
            markdownEnabled: false,
            typingSpeed: const Duration(milliseconds: 20),
            controller: controller,
          ),
        ),
      );
    }

    await tester.pumpWidget(build(controllerA));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    // Swap to a different controller instance mid-animation.
    await tester.pumpWidget(build(controllerB));
    await tester.pump();

    // The OLD controller must no longer receive commands from the widget,
    // and must not be left in a stale "animating forever" state.
    expect(controllerA.isCompleted, isFalse);

    // The NEW controller must now drive the widget: pausing it must
    // actually pause the reveal.
    controllerB.pause();
    await tester.pump();
    final beforePauseSpin = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    final afterPauseSpin = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join();
    expect(afterPauseSpin, beforePauseSpin, reason: 'the new controller must pause it');

    controllerB.resume();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(controllerB.isCompleted, isTrue, reason: 'the new controller drives completion');
  });

  testWidgets(
    'onCompleted/onComplete count == 1, including a tap after completion '
    '(W3, W25)',
    (tester) async {
      final controller = StreamingTextController();
      addTearDown(controller.dispose);
      var widgetOnCompleteCount = 0;
      var controllerOnCompletedCount = 0;
      controller.onCompleted(() => controllerOnCompletedCount++);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: 'short text',
              markdownEnabled: false,
              typingSpeed: const Duration(milliseconds: 5),
              controller: controller,
              onComplete: () => widgetOnCompleteCount++,
            ),
          ),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 5));
      }
      expect(widgetOnCompleteCount, 1);
      expect(controllerOnCompletedCount, 1);

      // A tap after completion is a no-op (W3): must not re-fire.
      await tester.tap(find.byType(StreamingText));
      await tester.pump();
      expect(widgetOnCompleteCount, 1);
      expect(controllerOnCompletedCount, 1);

      // updateProgress(1.0)/markCompleted-style redundant signals (driven by
      // the widget's own per-frame reporting) must never double-fire (W25).
      await tester.pump(const Duration(milliseconds: 50));
      expect(widgetOnCompleteCount, 1);
      expect(controllerOnCompletedCount, 1);
    },
  );

  testWidgets(
    'a rebuild with an unchanged source never re-fires completion (W3, W23)',
    (tester) async {
      const text = 'stable text';
      var completeCount = 0;
      var rebuildKey = 0;

      Widget build() {
        return MaterialApp(
          key: ValueKey(rebuildKey),
          home: Scaffold(
            body: StreamingText(
              text: text,
              markdownEnabled: false,
              animationsEnabled: false,
              onComplete: () => completeCount++,
            ),
          ),
        );
      }

      await tester.pumpWidget(build());
      await tester.pump();
      expect(completeCount, 1);

      // Rebuild with the exact same text/config (same element, no remount).
      await tester.pumpWidget(build());
      await tester.pump();
      expect(completeCount, 1, reason: 'an unchanged source must not re-fire onComplete');
    },
  );

  testWidgets(
    'plain fade over 5k chars keeps transientCallbackCount <= 2',
    (tester) async {
      final longText = List.generate(5000, (i) => 'a').join();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: longText,
              markdownEnabled: false,
              fadeInEnabled: true,
              fadeInDuration: const Duration(milliseconds: 200),
              animationsEnabled: false, // reveal instantly, then let the fade run
            ),
          ),
        ),
      );
      await tester.pump();

      var maxTransientCallbacks = 0;
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final count = SchedulerBinding.instance.transientCallbackCount;
        if (count > maxTransientCallbacks) maxTransientCallbacks = count;
      }

      expect(
        maxTransientCallbacks,
        lessThanOrEqualTo(2),
        reason:
            'a plain-text fade over 5k characters must use a single shared '
            'Ticker, never one AnimationController per glyph',
      );
    },
  );
}
