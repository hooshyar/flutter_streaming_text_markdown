// PHASE-B2-LEAN.md S1: the default code-block renderer.
//
// - a streamed fenced block renders CodeBlockView and grows
// - the copy button appears (enabled) only when the block is closed
// - a user codeBuilder overrides the default

import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/frames.dart';

void main() {
  Widget buildWidget(
    String text, {
    Widget Function(BuildContext, String, String, bool)? codeBuilder,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: StreamingText(
          revealMode: null,
          text: text,
          typingSpeed: const Duration(milliseconds: 16),
          wordByWord: false,
          markdownEnabled: true,
          showCursor: false,
          codeBuilder: codeBuilder,
        ),
      ),
    );
  }

  testWidgets(
    'a streamed fenced block renders CodeBlockView by default and grows',
    (tester) async {
      const text =
          'Before.\n\n```dart\nvoid main() {\n  print("hi");\n}\n```\nAfter.';
      await tester.pumpWidget(buildWidget(text));
      await tester.pump();

      var sawOpen = false;
      var lastLength = 0;
      for (var i = 0; i < 400; i++) {
        await pumpFrames(tester, 1);
        final views = tester.widgetList<CodeBlockView>(
          find.byType(CodeBlockView),
        );
        if (views.isEmpty) continue;
        final view = views.first;
        expect(view.code.length, greaterThanOrEqualTo(lastLength));
        lastLength = view.code.length;
        if (!view.closed) sawOpen = true;
        if (view.closed) break;
      }
      await pumpFrames(tester, 20);

      expect(
        find.byType(CodeBlockView),
        findsOneWidget,
        reason: 'default codeBuilder should render a CodeBlockView',
      );
      expect(sawOpen, isTrue, reason: 'never observed an open code block');

      final finalView = tester.widget<CodeBlockView>(
        find.byType(CodeBlockView),
      );
      expect(finalView.closed, isTrue);
      expect(finalView.code.trim(), contains('print("hi")'));
    },
  );

  testWidgets('the copy button is disabled while the block is open', (
    tester,
  ) async {
    const text = 'Before.\n\n```dart\nvoid main() {\n  print("hi");\n';
    await tester.pumpWidget(buildWidget(text));
    await tester.pump();
    await pumpFrames(tester, 200);

    final views = tester.widgetList<CodeBlockView>(find.byType(CodeBlockView));
    expect(views, isNotEmpty);
    expect(views.first.closed, isFalse);

    final copyButtons = find.widgetWithIcon(IconButton, Icons.copy_rounded);
    expect(copyButtons, findsWidgets);
    final button = tester.widget<IconButton>(copyButtons.first);
    expect(
      button.onPressed,
      isNull,
      reason: 'copy must be disabled while the block is still open',
    );
  });

  testWidgets('the copy button is enabled once the block is closed', (
    tester,
  ) async {
    const text = 'Before.\n\n```dart\nvoid main() {}\n```\nAfter.';
    await tester.pumpWidget(buildWidget(text));
    await tester.pump();

    CodeBlockView? closedView;
    for (var i = 0; i < 400; i++) {
      await pumpFrames(tester, 1);
      final views = tester.widgetList<CodeBlockView>(
        find.byType(CodeBlockView),
      );
      if (views.isNotEmpty && views.first.closed) {
        closedView = views.first;
        break;
      }
    }
    await pumpFrames(tester, 20);

    expect(closedView, isNotNull, reason: 'the fence never closed');

    final copyButtons = find.widgetWithIcon(IconButton, Icons.copy_rounded);
    expect(copyButtons, findsWidgets);
    final button = tester.widget<IconButton>(copyButtons.first);
    expect(button.onPressed, isNotNull);
  });

  testWidgets('a user codeBuilder overrides the default CodeBlockView', (
    tester,
  ) async {
    const text = 'Before.\n\n```dart\nvoid main() {}\n```\nAfter.';
    await tester.pumpWidget(
      buildWidget(
        text,
        codeBuilder:
            (context, name, code, closed) => Text('custom:$name:$closed:$code'),
      ),
    );
    await tester.pump();
    await pumpFrames(tester, 300);

    expect(find.byType(CodeBlockView), findsNothing);
    expect(find.textContaining('custom:dart:'), findsOneWidget);
  });
}
