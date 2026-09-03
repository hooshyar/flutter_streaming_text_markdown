import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/sections/customization_section.dart';

void main() {
  testWidgets(
    'Customization Preview toggle labels are not clipped by their switch thumbs',
    (WidgetTester tester) async {
      // Reproduces the 800px viewport from the 2026-09-03 QA pass, where
      // wordByWord/fadeIn/markdown/latex/animations labels lost their first
      // 1-3 characters behind the switch thumb.
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: CustomizationSection()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      const labels = [
        'wordByWord',
        'fadeIn',
        'markdown',
        'latex',
        'animations'
      ];
      for (final label in labels) {
        final textFinder = find.text(label);
        expect(textFinder, findsOneWidget,
            reason: 'toggle label "$label" not found');

        final rowFinder =
            find.ancestor(of: textFinder, matching: find.byType(Row)).first;
        final switchFinder =
            find.descendant(of: rowFinder, matching: find.byType(Switch));
        expect(switchFinder, findsOneWidget,
            reason: 'no Switch found alongside label "$label"');

        final switchRect = tester.getRect(switchFinder);
        final textRect = tester.getRect(textFinder);

        expect(
          textRect.left,
          greaterThanOrEqualTo(switchRect.right - 0.5),
          reason: 'label "$label" is clipped by its switch thumb '
              '(switch right=${switchRect.right}, text left=${textRect.left})',
        );
      }
    },
  );
}
