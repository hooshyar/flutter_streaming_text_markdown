// Copying from a code block: the check shows only after a successful
// clipboard write, and a refused write (the web, when the page isn't
// focused or clipboard permission is denied) no longer escapes as an
// uncaught error.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void mockClipboard(
    WidgetTester tester,
    Future<Object?> Function(MethodCall call) handler,
  ) {
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, handler);
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
  }

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('copy writes the code and shows the check', (tester) async {
    String? written;
    mockClipboard(tester, (call) async {
      if (call.method == 'Clipboard.setData') {
        written = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });

    await tester.pumpWidget(
      wrap(const CodeBlockView(code: 'void main() {}\n', language: 'dart')),
    );
    await tester.tap(find.byIcon(Icons.copy_rounded));
    await tester.pumpAndSettle();

    expect(written, 'void main() {}');
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    // Let the feedback timer run out before teardown.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('a refused clipboard write throws nothing and shows no check', (
    tester,
  ) async {
    mockClipboard(tester, (call) async {
      if (call.method == 'Clipboard.setData') {
        throw PlatformException(
          code: 'copy_fail',
          message: 'Clipboard.setData failed',
        );
      }
      return null;
    });

    await tester.pumpWidget(
      wrap(const CodeBlockView(code: 'void main() {}', language: 'dart')),
    );
    await tester.tap(find.byIcon(Icons.copy_rounded));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });
}
