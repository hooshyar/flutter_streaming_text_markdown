// CodeBlockView and CodeBlockTheme must be importable straight from the
// package barrel (flutter_streaming_text_markdown.dart), without reaching
// into `src/`, so consumers can theme or reuse the default code renderer.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

void main() {
  test('CodeBlockTheme is exported from the package barrel', () {
    expect(CodeBlockTheme, isNotNull);
    expect(const <Type>[CodeBlockTheme].single, CodeBlockTheme);
  });

  test('CodeBlockView is exported from the package barrel', () {
    expect(const <Type>[CodeBlockView].single, CodeBlockView);
    expect(CodeBlockView, isA<Type>());
    expect(const SizedBox(), isA<Widget>());
  });
}
