// Coverage for lib/src/render/caret_inline.dart: the caret sentinel, the
// InlinePattern that renders it as a WidgetSpan, and withCaretPattern's
// preservation of every other MarkdownRenderOptions field.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:flutter_streaming_text_markdown/src/render/caret_inline.dart';
import 'package:flutter_streaming_text_markdown/src/render/markdown_options.dart';

void main() {
  test('caretSentinel is the private-use-area marker, never real markdown',
      () {
    expect(caretSentinel, '');
  });

  group('caretInlinePattern', () {
    test('matches the sentinel and only the sentinel', () {
      final pattern = caretInlinePattern(const SizedBox());
      expect(pattern.pattern.hasMatch(caretSentinel), isTrue);
      expect(pattern.pattern.hasMatch('plain text'), isFalse);
    });

    testWidgets('builds a baseline-aligned WidgetSpan wrapping the caret',
        (tester) async {
      const caret = SizedBox(key: Key('caret'), width: 8, height: 8);
      final pattern = caretInlinePattern(caret);

      late InlineSpan span;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) {
            final match = pattern.pattern.firstMatch(caretSentinel)!;
            span = pattern.builder(context, match, const TextStyle());
            return const SizedBox();
          }),
        ),
      );

      expect(span, isA<WidgetSpan>());
      final widgetSpan = span as WidgetSpan;
      expect(widgetSpan.alignment, PlaceholderAlignment.baseline);
      expect(widgetSpan.baseline, TextBaseline.alphabetic);
      expect(widgetSpan.child, same(caret));
    });
  });

  group('withCaretPattern', () {
    test('appends the pattern to an empty options bundle', () {
      final pattern = caretInlinePattern(const SizedBox());
      final result = withCaretPattern(null, pattern);

      expect(result.inlinePatterns, [pattern]);
      expect(result.styleSheet, isNull);
      expect(result.autolink, isNull);
    });

    test('preserves every other field and appends after existing patterns',
        () {
      final existingPattern = InlinePattern(
        pattern: RegExp('existing'),
        builder: (context, match, style) => const TextSpan(text: 'x'),
      );
      final caretPattern = caretInlinePattern(const SizedBox());

      const styleSheet = GptMarkdownStyleSheet();
      final original = MarkdownRenderOptions(
        styleSheet: styleSheet,
        autolink: true,
        maxLines: 3,
        useDollarSignsForLatex: true,
        inlinePatterns: [existingPattern],
      );

      final result = withCaretPattern(original, caretPattern);

      expect(result.styleSheet, styleSheet);
      expect(result.autolink, isTrue);
      expect(result.maxLines, 3);
      expect(result.useDollarSignsForLatex, isTrue);
      expect(result.inlinePatterns, [existingPattern, caretPattern]);
    });
  });
}
