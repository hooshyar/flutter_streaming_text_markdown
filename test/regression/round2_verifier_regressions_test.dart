// Regression tests for the round-2 verifier's findings (2026-09-27). Each
// of these fails on 189b826 and passes after the round-2 fix commit. All
// pumps use realistic 16ms (60Hz) frames in loops, per the verifier's
// guidance — the bugs below specifically hide behind big pump jumps like
// `pumpAndSettle()` or a single multi-second `pump()`.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

String _rich(WidgetTester t) => find
    .byWidgetPredicate((w) => w is RichText)
    .evaluate()
    .map(
      (e) =>
          (e.widget as RichText).text.toPlainText(includePlaceholders: false),
    )
    .join('|');

Widget _host(Widget child, {bool reduce = false}) => MaterialApp(
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: SingleChildScrollView(child: child),
    ),
  ),
);

Future<void> _frames(WidgetTester t, int n, [int ms = 16]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(Duration(milliseconds: ms));
  }
}

void main() {
  group('A: controller + typingSpeed above ~16ms reveals at 60Hz frames', () {
    const text = 'A reasonably long sentence to reveal for the controller.';

    testWidgets('default typingSpeed (50ms) with a controller completes', (
      t,
    ) async {
      final controller = StreamingTextController();
      addTearDown(controller.dispose);
      await t.pumpWidget(
        _host(
          StreamingTextMarkdown(
            revealMode: null,
            text: text,
            controller: controller,
          ),
        ),
      );
      await _frames(t, 60); // ~1s of real 60Hz frames.
      expect(
        _rich(t),
        isNot(equals('')),
        reason:
            'nothing revealed after 1s of 16ms frames - the scheduler '
            'Timer never survives long enough to fire (fails on 189b826)',
      );
      await _frames(t, 240); // ~4s more.
      expect(_rich(t), text);
      expect(controller.state, StreamingTextState.completed);
    });

    testWidgets('.claude() preset with a controller completes', (t) async {
      final controller = StreamingTextController();
      addTearDown(controller.dispose);
      await t.pumpWidget(
        _host(
          StreamingTextMarkdown.claude(
            revealMode: null,
            text: text,
            controller: controller,
          ),
        ),
      );
      await _frames(t, 300);
      expect(_rich(t), text);
      expect(controller.state, StreamingTextState.completed);
    });

    testWidgets('pause/resume with a controller at 16ms frames', (t) async {
      final controller = StreamingTextController();
      addTearDown(controller.dispose);
      await t.pumpWidget(
        _host(
          StreamingTextMarkdown(
            revealMode: null,
            text: text,
            controller: controller,
            typingSpeed: const Duration(milliseconds: 40),
          ),
        ),
      );
      await _frames(t, 20);
      final beforePause = _rich(t);
      expect(
        beforePause,
        isNotEmpty,
        reason:
            'should have revealed something after 20 real frames '
            '(fails on 189b826)',
      );
      controller.pause();
      await _frames(t, 30);
      expect(
        _rich(t),
        beforePause,
        reason: 'text kept moving while the controller was paused',
      );
      controller.resume();
      await _frames(t, 300);
      expect(_rich(t), text);
      expect(controller.state, StreamingTextState.completed);
    });
  });

  group('B: a short append after completion is painted', () {
    for (final md in [false, true]) {
      for (final word in [false, true]) {
        testWidgets('SMALL APPEND md=$md word=$word', (t) async {
          Widget w(String s) => _host(
            StreamingText(
              revealMode: null,
              text: s,
              markdownEnabled: md,
              wordByWord: word,
              typingSpeed: const Duration(milliseconds: 10),
              chunkSize: 5,
            ),
          );
          await t.pumpWidget(w('Hello there'));
          await _frames(t, 100);
          expect(_rich(t), contains('Hello there'));

          await t.pumpWidget(w('Hello there ok'));
          await _frames(t, 100);
          expect(
            _rich(t),
            contains('Hello there ok'),
            reason:
                'the short post-completion append was never painted '
                '(fails on 189b826)',
          );
        });
      }
    }

    testWidgets('a longer append after completion is painted too', (t) async {
      Widget w(String s) => _host(
        StreamingText(
          revealMode: null,
          text: s,
          typingSpeed: const Duration(milliseconds: 10),
          chunkSize: 5,
        ),
      );
      await t.pumpWidget(w('Hello there'));
      await _frames(t, 100);
      const longer =
          'Hello there, this is a much longer follow-up sentence '
          'appended after completion.';
      await t.pumpWidget(w(longer));
      await _frames(t, 300);
      expect(_rich(t), contains(longer));
    });
  });

  group('C: reduced motion + stream reveals instantly', () {
    for (final md in [false, true]) {
      testWidgets('reduced motion md=$md tracks each chunk within one frame', (
        t,
      ) async {
        // Not `addTearDown(() => sc.close())`: this test already closes
        // the controller explicitly below, and awaiting `close()` twice on
        // a single-subscription controller mounted under a
        // `SingleChildScrollView` hangs the test binding's teardown.
        final sc = StreamController<String>();
        await t.pumpWidget(
          _host(
            StreamingTextMarkdown(
              revealMode: null,
              stream: sc.stream,
              markdownEnabled: md,
            ),
            reduce: true,
          ),
        );
        await _frames(t, 2);

        const chunks = ['Hel', 'lo ', 'there', ' friend'];
        var received = '';
        for (final c in chunks) {
          received += c;
          sc.add(c);
          // Exactly one realistic frame - not pumpAndSettle().
          await _frames(t, 1);
          final shown = _rich(t);
          expect(
            received.startsWith(shown),
            isTrue,
            reason:
                'shown "$shown" is not a literal prefix of received '
                '"$received"',
          );
          expect(
            received.length - shown.length,
            lessThanOrEqualTo(3),
            reason:
                'frozen well behind the stream instead of revealing '
                'instantly: shown="$shown" received="$received" '
                '(fails on 189b826, which stays frozen for 2s+)',
          );
        }
        await sc.close();
        await _frames(t, 3);
        expect(_rich(t), received);
      });
    }
  });

  group('D: an escaped dollar renders as literal text, not LaTeX', () {
    testWidgets(
      r'Literal \$x and \$y render as plain text with no Math span/exception',
      (t) async {
        await t.pumpWidget(
          _host(
            StreamingText(
              revealMode: null,
              text: r'Literal \$x and \$y here.',
              markdownEnabled: true,
              latexEnabled: true,
              animationsEnabled: false,
            ),
          ),
        );
        await _frames(t, 5);
        expect(t.takeException(), isNull);
        expect(find.byType(Math), findsNothing);
        expect(_rich(t), contains(r'$x'));
        expect(_rich(t), contains(r'$y'));
      },
    );
  });
}
