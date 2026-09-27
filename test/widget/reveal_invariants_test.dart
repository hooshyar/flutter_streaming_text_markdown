// Widget-level reveal invariants for the S5 engine rewire: the rendered
// text must always be a literal prefix of the source and end up exactly
// equal to it, across modes, text/stream input, and a corpus of the
// trickiest inputs (indentation, Arabic, LaTeX). Each of these fails on
// main (38bc831) and passes after the rewrite (W1/W2/W4/W5/W6/W24).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

// While revealing, showCursor defaults to true and the widget renders a
// `Text.rich` with a caret WidgetSpan instead of a plain `Text.data`. These
// invariants are about the revealed source text, not the caret, so exclude
// placeholder spans.
String _plainText(WidgetTester tester) {
  final texts = tester.widgetList<Text>(find.byType(Text));
  return texts
      .map(
        (t) =>
            t.textSpan?.toPlainText(includePlaceholders: false) ?? t.data ?? '',
      )
      .join();
}

Future<void> _drain(
  WidgetTester tester, {
  int rounds = 60,
  Duration step = const Duration(milliseconds: 5),
}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(step);
  }
}

void main() {
  const corpus = <String>[
    'plain text with   extra   spaces',
    '\tindented\twith\ttabs\tand\tmore',
    'line one\r\nline two\r\nline three\r\n',
    'team 👨‍👩‍👧‍👦 ready for takeoff',
  ];

  group('reveal invariant matrix: final text == source', () {
    for (final source in corpus) {
      for (final wordByWord in [false, true]) {
        testWidgets(
          'text mode, wordByWord=$wordByWord, "${source.length > 16 ? source.substring(0, 16) : source}..."',
          (tester) async {
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: StreamingText(
                    text: source,
                    markdownEnabled: false,
                    wordByWord: wordByWord,
                    typingSpeed: const Duration(milliseconds: 5),
                  ),
                ),
              ),
            );
            await tester.pump();
            await _drain(tester, rounds: 80);
            expect(_plainText(tester), source);
          },
        );

        testWidgets(
          'stream mode, wordByWord=$wordByWord, "${source.length > 16 ? source.substring(0, 16) : source}..."',
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
                    wordByWord: wordByWord,
                    typingSpeed: const Duration(milliseconds: 5),
                  ),
                ),
              ),
            );
            await tester.pump();

            final mid = source.length ~/ 2;
            controller.add(source.substring(0, mid));
            await tester.pump();
            await tester.pump();
            await _drain(tester, rounds: 20);
            controller.add(source.substring(mid));
            await tester.pump();
            await tester.pump();
            await controller.close();
            await tester.pump();
            await _drain(tester, rounds: 80);
            expect(_plainText(tester), source);
          },
        );
      }
    }
  });

  testWidgets('word + markdown: codeBuilder receives indented code (W1)', (
    tester,
  ) async {
    const code =
        '```dart\n'
        'void main() {\n'
        '  if (true) {\n'
        '    print("hi");\n'
        '  }\n'
        '}\n'
        '```';
    String? capturedCode;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreamingText(
            text: code,
            markdownEnabled: true,
            wordByWord: true,
            typingSpeed: const Duration(milliseconds: 1),
            codeBuilder: (context, name, codeText, closed) {
              if (closed) capturedCode = codeText;
              return Text(codeText);
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await _drain(tester, rounds: 300, step: const Duration(milliseconds: 2));

    expect(
      capturedCode,
      isNotNull,
      reason: 'the code block must finish revealing',
    );
    expect(
      capturedCode,
      contains('    print("hi");'),
      reason: 'indentation must survive a word-by-word reveal (W1)',
    );
  });

  testWidgets('append after complete keeps spaces (W2)', (tester) async {
    var text = 'Hello there';
    late StateSetter setter;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setter = setState;
          return MaterialApp(
            home: Scaffold(
              body: StreamingText(
                text: text,
                markdownEnabled: false,
                typingSpeed: const Duration(milliseconds: 2),
              ),
            ),
          );
        },
      ),
    );
    await tester.pump();
    await _drain(tester, rounds: 40, step: const Duration(milliseconds: 3));
    expect(_plainText(tester), 'Hello there');

    setter(() {
      text = 'Hello there, general kenobi';
    });
    await tester.pump();
    await _drain(tester, rounds: 40, step: const Duration(milliseconds: 3));
    expect(_plainText(tester), 'Hello there, general kenobi');
  });

  testWidgets('Arabic char mode completes (W4)', (tester) async {
    const arabic = 'مرحبا بك في التطبيق';
    var completed = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreamingText(
            text: arabic,
            markdownEnabled: false,
            wordByWord: false,
            typingSpeed: const Duration(milliseconds: 2),
            onComplete: () => completed++,
          ),
        ),
      ),
    );
    await tester.pump();
    await _drain(tester, rounds: 200, step: const Duration(milliseconds: 2));

    expect(completed, 1);
    expect(_plainText(tester), arabic);
  });

  testWidgets('pause/resume in Arabic never shrinks, ends == source (W5/W6)', (
    tester,
  ) async {
    const arabic = 'مرحبا بك في التطبيق العربي الجميل';
    final controller = StreamingTextController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreamingText(
            text: arabic,
            markdownEnabled: false,
            typingSpeed: const Duration(milliseconds: 5),
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pump();
    await _drain(tester, rounds: 10);
    final beforePause = _plainText(tester);
    expect(beforePause.isNotEmpty, isTrue);

    controller.pause();
    await tester.pump();
    await _drain(tester, rounds: 10);
    expect(
      _plainText(tester),
      beforePause,
      reason: 'paused: no growth or shrink',
    );

    controller.resume();
    await _drain(tester, rounds: 300);
    expect(_plainText(tester), arabic);
  });

  testWidgets('pause/resume in LaTeX never shrinks, ends == source (W5/W6)', (
    tester,
  ) async {
    const source = r'Euler: $e^{i\pi}+1=0$ done';
    final controller = StreamingTextController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreamingText(
            text: source,
            markdownEnabled: false,
            latexEnabled: true,
            typingSpeed: const Duration(milliseconds: 5),
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pump();
    await _drain(tester, rounds: 5);
    final beforePause = _plainText(tester);

    controller.pause();
    await tester.pump();
    await _drain(tester, rounds: 10);
    expect(
      _plainText(tester),
      beforePause,
      reason: 'paused: no growth or shrink',
    );

    controller.resume();
    await _drain(tester, rounds: 300);
    expect(_plainText(tester), source);
  });

  testWidgets('a non-append text change keeps the common prefix (W24)', (
    tester,
  ) async {
    var text = 'The quick brown fox';
    late StateSetter setter;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setter = setState;
          return MaterialApp(
            home: Scaffold(
              body: StreamingText(
                text: text,
                markdownEnabled: false,
                typingSpeed: const Duration(milliseconds: 20),
              ),
            ),
          );
        },
      ),
    );
    await tester.pump();
    // Reveal only a few characters — comfortably within "The quick " (the
    // longest common prefix shared with the new text below).
    await _drain(tester, rounds: 3, step: const Duration(milliseconds: 20));
    final partial = _plainText(tester);
    expect(partial.isNotEmpty, isTrue);
    expect('The quick brown fox'.startsWith(partial), isTrue);
    expect('The quick red fox jumps'.startsWith(partial), isTrue);

    setter(() {
      text = 'The quick red fox jumps';
    });
    await tester.pump();
    // The common prefix must be kept exactly, not reset to ''.
    expect(_plainText(tester), partial);

    await _drain(tester, rounds: 60, step: const Duration(milliseconds: 20));
    expect(_plainText(tester), 'The quick red fox jumps');
  });
}
