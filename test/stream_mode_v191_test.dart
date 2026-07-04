import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

void main() {
  group('v1.9.1 slice 1 — cursor ticker', () {
    testWidgets('no repeating ticker after animation completes',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StreamingText(
            text: 'Hello World',
            typingSpeed: Duration(milliseconds: 10),
            markdownEnabled: false,
          ),
        ),
      );

      // showCursor defaults to true — this exercises the default config.
      await tester.pump();
      // "Hello World" is 11 characters; give it plenty of time to finish
      // typing with a margin of pumps.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      // If a ticker (e.g. the cursor AnimationController) is still
      // repeating, pumpAndSettle throws a FlutterError ("did not settle")
      // instead of returning — so simply completing here is the assertion.
      await tester.pumpAndSettle();

      expect(find.byType(StreamingText), findsOneWidget);
    });

    testWidgets('pumpAndSettle completes with showCursor explicitly true',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StreamingText(
            text: 'Test',
            typingSpeed: Duration(milliseconds: 5),
            showCursor: true,
            cursorColor: Colors.red,
            markdownEnabled: false,
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(StreamingText), findsOneWidget);
    });
  });
}
