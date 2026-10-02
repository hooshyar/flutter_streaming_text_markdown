// StreamingTextMarkdown's new API-honesty params (markdownOptions,
// selectable, showCursor, cursorColor, semanticsLabel, errorBuilder) must
// actually reach the inner StreamingText - none of these existed as
// StreamingTextMarkdown constructor params on 38bc831, so this file fails to
// compile there.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

void main() {
  testWidgets('forwards markdownOptions/selectable/showCursor/cursorColor/'
      'semanticsLabel/errorBuilder to the inner StreamingText', (tester) async {
    const options = MarkdownRenderOptions(autolink: false);
    Widget errorBuilder(BuildContext context, Object error) =>
        const SizedBox.shrink();

    await tester.pumpWidget(
      MaterialApp(
        home: StreamingTextMarkdown(
          revealMode: null,
          text: 'hello',
          markdownOptions: options,
          selectable: true,
          showCursor: false,
          cursorColor: const Color(0xFF112233),
          semanticsLabel: 'greeting',
          errorBuilder: errorBuilder,
        ),
      ),
    );
    await tester.pump();

    final inner = tester.widget<StreamingText>(find.byType(StreamingText));
    expect(inner.markdownOptions, same(options));
    expect(inner.selectable, isTrue);
    expect(inner.showCursor, isFalse);
    expect(inner.cursorColor, const Color(0xFF112233));
    expect(inner.semanticsLabel, 'greeting');
    expect(inner.errorBuilder, same(errorBuilder));
  });

  testWidgets('showCursor null resolves to stream != null (assumption from '
      'PHASE-A-PLAN.md)', (tester) async {
    final controller = StreamController<String>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(
        home: StreamingTextMarkdown(
          revealMode: null,
          stream: controller.stream,
        ),
      ),
    );
    await tester.pump();
    var inner = tester.widget<StreamingText>(find.byType(StreamingText));
    expect(inner.showCursor, isTrue, reason: 'stream != null -> true');

    await tester.pumpWidget(
      const MaterialApp(
        home: StreamingTextMarkdown(
          revealMode: null,
          text: 'hi',
          animationsEnabled: false,
        ),
      ),
    );
    await tester.pump();
    inner = tester.widget<StreamingText>(find.byType(StreamingText));
    expect(inner.showCursor, isFalse, reason: 'stream == null -> false');
  });
}
