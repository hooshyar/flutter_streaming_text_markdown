import 'package:flutter_test/flutter_test.dart';

/// One real Flutter engine frame interval - what every streaming widget test
/// in this package pumps instead of `pumpAndSettle`, per PHASE-B1-PLAN.md's
/// GLOBAL RULES: `pumpAndSettle` must never run while a stream, caret pulse
/// or fade animation is still open, since none of those ever naturally
/// settle on their own mid-reveal.
const Duration frameInterval = Duration(milliseconds: 16);

/// Pumps [count] real 16ms frames (or [frame] when overridden).
Future<void> pumpFrames(
  WidgetTester tester,
  int count, {
  Duration frame = frameInterval,
}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(frame);
  }
}

/// Pumps whole 16ms frames until at least [duration] has elapsed.
Future<void> pumpFor(
  WidgetTester tester,
  Duration duration, {
  Duration frame = frameInterval,
}) async {
  final frames = (duration.inMicroseconds / frame.inMicroseconds).ceil();
  await pumpFrames(tester, frames, frame: frame);
}
