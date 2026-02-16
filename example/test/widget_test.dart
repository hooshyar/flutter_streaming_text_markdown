import 'package:flutter_test/flutter_test.dart';
import 'package:example/main.dart';

void main() {
  testWidgets('Example app loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.byType(ExampleApp), findsOneWidget);
    await tester.pump();
  });
}
