import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression coverage for the code-fence render stabilization in
/// `_buildSimpleMarkdown`/`_stableRenderText`.
///
/// The widget types [text] out character-by-character internally, via its
/// own timer, independent of how the caller supplied it. While its internal
/// display buffer is mid-way through an (eventually-complete) ``` code
/// fence, gpt_markdown shows that fence's content as raw, unstyled text —
/// including the literal backtick characters as they're typed. The instant
/// the internal buffer finishes typing the closing fence, gpt_markdown
/// recognizes the block and reformats it as a styled code widget, which
/// strips the fence markers from the visible output. Rendered at that
/// transition, the visible text must never get SHORTER — that shrink is
/// what reads as a stutter on top of the typing animation.
void main() {
  Widget build(String text) => MaterialApp(
        home: Scaffold(
          body: StreamingText(
            text: text,
            typingSpeed: const Duration(milliseconds: 5),
            wordByWord: false,
            markdownEnabled: true,
            showCursor: false,
          ),
        ),
      );

  testWidgets(
      'internal per-character typing through a closing fence never shows '
      'shrinking visible text or raw fence markers', (tester) async {
    final handle = tester.ensureSemantics();

    const text = 'Here you go:\n```dart\nfinal x = 1;\nfinal y = 2;\n```\n'
        'Done.';
    await tester.pumpWidget(build(text));

    // Advance the internal typing timer tick-by-tick across the whole
    // response, watching for a raw fence marker appearing in the output.
    // (Total semantics-tree length isn't a reliable proxy here — a code
    // block's surrounding chrome, like a language tag or "Copy" button,
    // changes the tree structure independent of the actual content text.)
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 5));
      final rendered =
          tester.getSemantics(find.byType(MaterialApp)).toStringDeep();
      expect(rendered, isNot(contains('```')),
          reason: 'Raw fence markers rendered mid-typing at tick $i');
    }

    // Let any remaining animation settle, then confirm the final content
    // actually rendered (not permanently withheld).
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.textContaining('final x = 1;'), findsWidgets);
    expect(find.textContaining('Done.'), findsOneWidget);

    handle.dispose();
  });
}
