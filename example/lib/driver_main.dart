// Entrypoint for tool-driven UI verification (flutter_driver).
// Run with: flutter run -t lib/driver_main.dart
import 'package:flutter_driver/driver_extension.dart';

import 'main.dart' as app;

void main() {
  enableFlutterDriverExtension();
  app.main();
}
