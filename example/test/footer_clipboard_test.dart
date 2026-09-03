import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/sections/footer_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpFooter(WidgetTester tester) {
    return tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FooterSection()),
      ),
    );
  }

  testWidgets(
    'copy-to-clipboard tap does not throw when the platform channel rejects',
    (WidgetTester tester) async {
      // Simulates the web failure mode from the 2026-09-03 QA pass: the
      // browser's Clipboard.setData platform call rejects, which must be
      // caught rather than left as an unhandled Future exception.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            throw PlatformException(code: 'error', message: 'denied');
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      await pumpFooter(tester);
      await tester.tap(find.byIcon(Icons.copy));
      // Pumping must complete cleanly: a leftover unawaited/uncaught
      // Future rejection would surface as a FlutterError during this pump.
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not copy'), findsOneWidget);
    },
  );

  testWidgets(
    'copy-to-clipboard tap shows the success toast when the platform call succeeds',
    (WidgetTester tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async => null,
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      await pumpFooter(tester);
      await tester.tap(find.byIcon(Icons.copy));
      await tester.pumpAndSettle();

      expect(find.text('Copied to clipboard'), findsOneWidget);
    },
  );
}
