// StreamingShimmer and MarkdownRenderOptions must be importable straight from
// the package barrel (flutter_streaming_text_markdown.dart), without reaching
// into `src/`. On 38bc831, StreamingShimmer was only imported internally (not
// exported) and MarkdownRenderOptions did not exist, so this file fails to
// compile there.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

void main() {
  testWidgets('StreamingShimmer is importable from the package barrel', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: StreamingShimmer()));
    await tester.pump();
    expect(find.byType(StreamingShimmer), findsOneWidget);
  });

  test('MarkdownRenderOptions is importable from the package barrel', () {
    const options = MarkdownRenderOptions(autolink: true);
    expect(options.autolink, isTrue);
  });
}
