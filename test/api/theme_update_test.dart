// Regression test for W8-adjacent theme-caching bug: on 38bc831,
// `_StreamingTextMarkdownState` cached `widget.theme ?? context.streamingTextTheme`
// in `didChangeDependencies`, which only re-runs when an ancestor
// InheritedWidget changes - not when the caller simply passes a new `theme:`
// value on rebuild. Swapping `theme` directly therefore never restyled the
// output. Fixed by resolving the effective theme fresh inside `build`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

void main() {
  testWidgets('swapping widget.theme directly restyles the rendered text', (
    tester,
  ) async {
    const themeA = StreamingTextTheme(textStyle: TextStyle(color: Colors.red));
    const themeB = StreamingTextTheme(textStyle: TextStyle(color: Colors.blue));

    await tester.pumpWidget(
      const MaterialApp(
        home: StreamingTextMarkdown(
          text: 'hello',
          theme: themeA,
          animationsEnabled: false,
        ),
      ),
    );
    await tester.pump();

    Text textWidget = tester.widget<Text>(find.byType(Text).first);
    expect(textWidget.style?.color, Colors.red);

    // Same widget position/type, only `theme` changes - no ancestor
    // InheritedWidget change, so `didChangeDependencies` would not fire.
    await tester.pumpWidget(
      const MaterialApp(
        home: StreamingTextMarkdown(
          text: 'hello',
          theme: themeB,
          animationsEnabled: false,
        ),
      ),
    );
    await tester.pump();

    textWidget = tester.widget<Text>(find.byType(Text).first);
    expect(textWidget.style?.color, Colors.blue);
  });
}
