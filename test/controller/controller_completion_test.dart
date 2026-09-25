import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

void main() {
  group('StreamingTextController completion latch (W25)', () {
    test(
        'onCompleted fires once for updateProgress(1) then markCompleted '
        '(fails on main, which fires twice)', () {
      final controller = StreamingTextController();
      var completedCount = 0;
      controller.onCompleted(() => completedCount++);

      controller.updateProgress(1.0);
      controller.markCompleted();

      expect(completedCount, 1);
      expect(controller.isCompleted, isTrue);
      expect(controller.state, StreamingTextState.completed);
    });

    test('onCompleted fires once for skipToEnd then markCompleted', () {
      final controller = StreamingTextController();
      var completedCount = 0;
      controller.onCompleted(() => completedCount++);

      controller.skipToEnd();
      controller.markCompleted();
      controller.updateProgress(1.0);

      expect(completedCount, 1);
    });

    test('restart re-arms the latch for a new cycle', () {
      final controller = StreamingTextController();
      var completedCount = 0;
      controller.onCompleted(() => completedCount++);

      controller.markCompleted();
      expect(completedCount, 1);

      controller.restart();
      expect(controller.isCompleted, isFalse);
      expect(controller.state, StreamingTextState.animating);

      controller.markCompleted();
      expect(completedCount, 2);
    });

    test('stop re-arms the latch for a new cycle', () {
      final controller = StreamingTextController();
      var completedCount = 0;
      controller.onCompleted(() => completedCount++);

      controller.markCompleted();
      expect(completedCount, 1);

      controller.stop();
      expect(controller.isCompleted, isFalse);
      expect(controller.state, StreamingTextState.idle);

      controller.updateProgress(1.0);
      expect(completedCount, 2);
    });
  });

  group('StreamingTextController.markError', () {
    test('sets the error state and exposes the error', () {
      final controller = StreamingTextController();
      final error = StateError('boom');

      controller.markError(error);

      expect(controller.state, StreamingTextState.error);
      expect(controller.error, same(error));
    });

    test('stop and restart clear the error', () {
      final controller = StreamingTextController();
      controller.markError(StateError('boom'));
      expect(controller.error, isNotNull);

      controller.stop();
      expect(controller.error, isNull);

      controller.markError(StateError('boom again'));
      controller.restart();
      expect(controller.error, isNull);
    });
  });
}
