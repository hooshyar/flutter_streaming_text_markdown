// PHASE-B2-LEAN.md S1: a highlighter smoke test for Dart and JSON.

import 'package:flutter/painting.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'package:flutter_streaming_text_markdown/src/render/code/code_highlighter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const highlighter = CodeHighlighter();
  final theme = CodeBlockTheme.light();

  TextSpan highlight(String code, {String? language, bool enabled = true}) =>
      highlighter.highlight(
        code,
        language: language,
        theme: theme,
        enabled: enabled,
      );

  group('CodeHighlighter smoke test', () {
    test('Dart source tokenizes into multiple styled spans', () {
      const dart = '''
// a comment
class Foo {
  final int bar = 42;
  String baz() => "hi";
}
''';
      final span = highlight(dart, language: 'dart');
      expect(span.toPlainText(), dart);

      final colors = <Color?>{};
      void collect(InlineSpan s) {
        if (s is TextSpan) {
          colors.add(s.style?.color);
          s.children?.forEach(collect);
        }
      }

      collect(span);
      // More than a single flat colour proves real tokenization ran
      // (comment, keyword, string, number all differ from plain text).
      expect(
        colors.length,
        greaterThan(1),
        reason: 'expected multiple token colours, got: $colors',
      );
    });

    test('JSON source tokenizes without throwing', () {
      const json = '{"name": "test", "count": 3, "ok": true}';
      final span = highlight(json, language: 'json');
      expect(span.toPlainText(), json);

      final colors = <Color?>{};
      void collect(InlineSpan s) {
        if (s is TextSpan) {
          colors.add(s.style?.color);
          s.children?.forEach(collect);
        }
      }

      collect(span);
      expect(colors.length, greaterThan(1));
    });

    test('disabled highlighting returns a single plain span', () {
      const dart = 'final x = 1;';
      final span = highlight(dart, language: 'dart', enabled: false);
      expect(span.toPlainText(), dart);
      expect(span.children, anyOf(isNull, isEmpty));
    });

    test('unknown language does not throw', () {
      const code = 'some ~~weird~~ text';
      expect(
        () => highlight(code, language: 'not-a-real-lang'),
        returnsNormally,
      );
    });
  });
}
