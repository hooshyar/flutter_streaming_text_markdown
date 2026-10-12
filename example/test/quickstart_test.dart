import 'package:example/quickstart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the README quick start streams its whole reply in', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ReplyView())),
    );
    expect(find.byType(StreamingTextMarkdown), findsOneWidget);

    // Let the fake stream deliver every token and the reveal finish.
    for (var i = 0; i < 150; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('markdown is re-rendered', findRichText: true),
      findsOneWidget,
    );
  });
}
