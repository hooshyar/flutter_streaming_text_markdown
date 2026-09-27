// Acceptance criterion 3: an open fence renders a growing code block.
// `codeBuilder` receives `closed: false` with `code` growing line by line,
// then `closed: true` once the fence closes. A partial opener line with no
// newline yet renders nothing. The caret sentinel never appears in the
// `code` string.

import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/frames.dart';

class _CodeCall {
  const _CodeCall(this.name, this.code, this.closed);
  final String name;
  final String code;
  final bool closed;
}

void main() {
  Widget buildWidget(
    String text,
    List<_CodeCall> calls, {
    bool showCursor = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: StreamingText(
          revealMode: null,
          text: text,
          typingSpeed: const Duration(milliseconds: 16),
          wordByWord: false,
          markdownEnabled: true,
          showCursor: showCursor,
          codeBuilder: (context, name, code, closed) {
            calls.add(_CodeCall(name, code, closed));
            return Text('[$name:$closed]\n$code');
          },
        ),
      ),
    );
  }

  testWidgets(
    'a growing fence calls codeBuilder with closed:false and growing code, '
    'then closed:true once it closes',
    (tester) async {
      final calls = <_CodeCall>[];
      const text =
          'Before.\n\n```dart\nvoid main() {\n  print("hi");\n}\n```\nAfter.';
      await tester.pumpWidget(buildWidget(text, calls));
      await tester.pump();

      // Pump real 16ms frames across the whole reveal - never
      // `pumpAndSettle` while the caret/stream is open.
      for (var i = 0; i < 400 && calls.where((c) => c.closed).isEmpty; i++) {
        await pumpFrames(tester, 1);
      }
      // Let the trailing caret/fade settle down after completion.
      await pumpFrames(tester, 40);

      expect(calls, isNotEmpty, reason: 'codeBuilder was never invoked');

      final openCalls = calls.where((c) => !c.closed).toList();
      expect(
        openCalls,
        isNotEmpty,
        reason: 'never observed an open (closed:false) code block',
      );

      // The code string grows (non-strictly - some frames may repeat the
      // same length) across the open calls, and never shrinks.
      var lastLength = 0;
      for (final call in openCalls) {
        expect(call.code.length, greaterThanOrEqualTo(lastLength));
        lastLength = call.code.length;
      }

      final closedCalls = calls.where((c) => c.closed).toList();
      expect(
        closedCalls,
        isNotEmpty,
        reason: 'fence never closed once the ``` arrived',
      );
      expect(closedCalls.last.code.trim(), contains('print("hi")'));

      // The caret sentinel (U+E000) must never reach the code string.
      for (final call in calls) {
        expect(
          call.code.contains(''),
          isFalse,
          reason: 'caret sentinel leaked into codeBuilder: "${call.code}"',
        );
      }
    },
  );

  testWidgets(
    'a partial fence-opener line with no newline yet renders nothing',
    (tester) async {
      final calls = <_CodeCall>[];
      // Typed one character at a time: `typingSpeed` is tiny so the very
      // first frames only reveal "``" / "```" / "```d" of "```dart" with no
      // trailing newline yet - `mend` must hold that whole line back, so
      // `codeBuilder` is never invoked for it.
      const text = 'Before.\n\n```dart';
      await tester.pumpWidget(buildWidget(text, calls, showCursor: false));
      await tester.pump();

      // Only reveal the first few characters of the opener line - not
      // enough for the fence to have a trailing newline yet.
      await pumpFrames(tester, 6);

      expect(
        calls,
        isEmpty,
        reason:
            'codeBuilder fired before the fence opener line even finished '
            'being typed: $calls',
      );

      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      final visible = richTexts.map((t) => t.text.toPlainText()).join();
      expect(visible.contains('```'), isFalse);
    },
  );
}
