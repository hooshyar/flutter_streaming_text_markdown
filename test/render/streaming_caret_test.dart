import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/widgets.dart';
import 'package:flutter_streaming_text_markdown/src/render/streaming_caret.dart';
import 'package:flutter_streaming_text_markdown/src/theme/streaming_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('caretPulseOpacity', () {
    test('sine in-out stays within 0.35 and 1.0 over several cycles', () {
      var minSeen = 1.0;
      var maxSeen = 0.0;
      // Sample across multiple 900ms cycles at a non-divisor step.
      for (var us = 0; us < 3 * 900 * 1000; us += 7000) {
        final o = caretPulseOpacity(Duration(microseconds: us));
        expect(o, greaterThanOrEqualTo(caretPulseMinOpacity - 1e-9));
        expect(o, lessThanOrEqualTo(1.0 + 1e-9));
        if (o < minSeen) minSeen = o;
        if (o > maxSeen) maxSeen = o;
      }
      expect(minSeen, closeTo(caretPulseMinOpacity, 0.02));
      expect(maxSeen, closeTo(1.0, 0.02));
    });

    test('hits the extremes at the cycle boundaries', () {
      expect(caretPulseOpacity(Duration.zero), closeTo(0.35, 1e-9));
      expect(
        caretPulseOpacity(const Duration(milliseconds: 450)),
        closeTo(1.0, 1e-9),
      );
      expect(
        caretPulseOpacity(const Duration(milliseconds: 900)),
        closeTo(0.35, 1e-9),
      );
    });

    test('is a constant 1.0 under reduced motion', () {
      for (var ms = 0; ms <= 2000; ms += 37) {
        expect(
          caretPulseOpacity(Duration(milliseconds: ms), reducedMotion: true),
          1.0,
        );
      }
    });
  });

  group('StreamingCaret', () {
    testWidgets('renders an 8x8 circle at the given opacity', (tester) async {
      final opacity = ValueNotifier<double>(0.5);
      addTearDown(opacity.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: StreamingCaret(
              opacity: opacity,
              color: const Color(0xFF18181B),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(StreamingCaret)), const Size(8, 8));

      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(StreamingCaret),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color!.a, closeTo(0.5, 0.01));
    });

    testWidgets(
      'repaints from its own listenable without an external rebuild',
      (tester) async {
        final opacity = ValueNotifier<double>(1.0);
        addTearDown(opacity.dispose);
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: StreamingCaret(
                opacity: opacity,
                color: const Color(0xFF18181B),
              ),
            ),
          ),
        );

        opacity.value = 0.35;
        await tester.pump();

        final box = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(StreamingCaret),
            matching: find.byType(DecoratedBox),
          ),
        );
        final decoration = box.decoration as BoxDecoration;
        expect(decoration.color!.a, closeTo(0.35, 0.01));
      },
    );
  });

  group('StreamingTokens', () {
    test('resolves the DESIGN.md hex values per brightness', () {
      final light = StreamingTokens.of(Brightness.light);
      expect(light.textPrimary, const Color(0xFF18181B));
      expect(light.textTertiary, const Color(0xFF6B6B73));
      expect(light.danger, const Color(0xFFC4321C));

      final dark = StreamingTokens.of(Brightness.dark);
      expect(dark.textPrimary, const Color(0xFFEDEDEF));
      expect(dark.textTertiary, const Color(0xFF8C8C94));
      expect(dark.danger, const Color(0xFFFF7A66));
    });
  });
}
