// Coverage for lib/src/theme/streaming_text_theme.dart: the
// StreamingTextTheme ThemeExtension (defaults factory, copyWith, lerp) and
// the BuildContext.streamingTextTheme accessor.
// ignore_for_file: deprecated_member_use, deprecated_member_use_from_same_package

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

void main() {
  testWidgets('StreamingTextTheme.defaults derives from the ambient Theme',
      (tester) async {
    late StreamingTextTheme theme;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          textTheme: const TextTheme(bodyLarge: TextStyle(fontSize: 20)),
        ),
        home: Builder(builder: (context) {
          theme = StreamingTextTheme.defaults(context);
          return const SizedBox();
        }),
      ),
    );

    expect(theme.textStyle?.fontSize, 20);
    expect(theme.markdownStyleSheet?.fontSize, 20);
    expect(theme.defaultPadding, const EdgeInsets.all(16.0));
    expect(theme.inlineLatexStyle?.fontSize, 22); // 20 * 1.1
    expect(theme.blockLatexStyle?.fontSize, 24); // 20 * 1.2
    expect(theme.latexScale, 1.0);
    expect(theme.latexFadeInEnabled, isFalse);
  });

  testWidgets(
      'context.streamingTextTheme falls back to defaults when no extension '
      'is registered', (tester) async {
    late StreamingTextTheme resolved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(builder: (context) {
          resolved = context.streamingTextTheme;
          return const SizedBox();
        }),
      ),
    );

    expect(resolved.textStyle, isNotNull);
  });

  testWidgets(
      'context.streamingTextTheme returns a registered ThemeExtension',
      (tester) async {
    const custom = StreamingTextTheme(
      textStyle: TextStyle(fontSize: 42),
    );
    late StreamingTextTheme resolved;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [custom]),
        home: Builder(builder: (context) {
          resolved = context.streamingTextTheme;
          return const SizedBox();
        }),
      ),
    );

    expect(resolved.textStyle?.fontSize, 42);
  });

  group('copyWith', () {
    test('overrides only the given fields', () {
      const base = StreamingTextTheme(
        textStyle: TextStyle(fontSize: 10),
        defaultPadding: EdgeInsets.all(4),
      );

      final updated = base.copyWith(textStyle: const TextStyle(fontSize: 30));

      expect(updated.textStyle?.fontSize, 30);
      expect(updated.defaultPadding, const EdgeInsets.all(4));
    });

    test('markdownStyleSheet falls back to legacy markdownStyle', () {
      const base = StreamingTextTheme(
        markdownStyle: TextStyle(fontSize: 12),
      );

      final updated = base.copyWith();

      expect(updated.markdownStyleSheet?.fontSize, 12);
    });
  });

  group('lerp', () {
    test('interpolates numeric and style fields', () {
      const a = StreamingTextTheme(
        textStyle: TextStyle(fontSize: 10),
        defaultPadding: EdgeInsets.all(0),
        latexScale: 1.0,
      );
      const b = StreamingTextTheme(
        textStyle: TextStyle(fontSize: 20),
        defaultPadding: EdgeInsets.all(10),
        latexScale: 2.0,
      );

      final mid = a.lerp(b, 0.5);

      expect(mid.textStyle?.fontSize, 15);
      expect(mid.defaultPadding, const EdgeInsets.all(5));
      expect(mid.latexScale, 1.5);
    });

    test('returns this unchanged for a non-matching extension type', () {
      const a = StreamingTextTheme(textStyle: TextStyle(fontSize: 10));
      final result = a.lerp(null, 0.5);
      expect(result, same(a));
    });

    test('latexFadeInEnabled switches at the midpoint', () {
      const a = StreamingTextTheme(latexFadeInEnabled: true);
      const b = StreamingTextTheme(latexFadeInEnabled: false);

      expect(a.lerp(b, 0.2).latexFadeInEnabled, isTrue);
      expect(a.lerp(b, 0.8).latexFadeInEnabled, isFalse);
    });
  });
}
