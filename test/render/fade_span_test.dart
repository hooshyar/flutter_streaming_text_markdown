import 'package:flutter/widgets.dart';
import 'package:flutter_streaming_text_markdown/src/render/fade_span.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const style = TextStyle(color: Color(0xFF18181B), fontSize: 16);
  const fade = Duration(milliseconds: 180);
  const text = 'hello world';

  group('buildFadeSpan', () {
    test('empty runs produce a single plain span equal to the input', () {
      final span = buildFadeSpan(
        text: text,
        runs: const [],
        now: Duration.zero,
        fadeDuration: fade,
        curve: Curves.linear,
        style: style,
      );
      expect(span.toPlainText(), text);
      expect((span as TextSpan).children, isNull);
    });

    test('settled runs merge into a plain span equal to the input', () {
      final span = buildFadeSpan(
        text: text,
        runs: const [FadeRun(6, 11, Duration.zero)],
        now: const Duration(seconds: 1),
        fadeDuration: fade,
        curve: Curves.linear,
        style: style,
      );
      expect(span.toPlainText(), text);
      expect((span as TextSpan).children, isNull);
    });

    test('produces one settled prefix plus one alpha span per fading run', () {
      const now = Duration(milliseconds: 90); // t = 0.5
      final span = buildFadeSpan(
        text: text,
        runs: const [FadeRun(6, 11, Duration.zero)],
        now: now,
        fadeDuration: fade,
        curve: Curves.linear,
        style: style,
      ) as TextSpan;

      expect(span.toPlainText(), text);
      final children = span.children!;
      expect(children.length, 2);

      final prefix = children[0] as TextSpan;
      expect(prefix.text, 'hello ');
      expect(prefix.style!.color, style.color);

      final run = children[1] as TextSpan;
      expect(run.text, 'world');
      expect(run.style!.color!.a, closeTo(0.5, 0.01));
    });

    test('fading run alpha follows the curve over time', () {
      FadeRun run(int start) => FadeRun(start, text.length, Duration.zero);
      double alphaAt(Duration now) {
        final span = buildFadeSpan(
          text: text,
          runs: [run(6)],
          now: now,
          fadeDuration: fade,
          curve: Curves.linear,
          style: style,
        ) as TextSpan;
        final runSpan = span.children!.last as TextSpan;
        return runSpan.style!.color!.a;
      }

      expect(alphaAt(Duration.zero), closeTo(0.0, 0.01));
      expect(alphaAt(const Duration(milliseconds: 45)), closeTo(0.25, 0.01));
      expect(alphaAt(const Duration(milliseconds: 179)), closeTo(0.99, 0.01));
    });

    test('plain text always equals the input, at every fade instant', () {
      for (var ms = 0; ms <= 200; ms += 20) {
        final span = buildFadeSpan(
          text: text,
          runs: const [
            FadeRun(0, 5, Duration.zero),
            FadeRun(6, 11, Duration(milliseconds: 60)),
          ],
          now: Duration(milliseconds: ms),
          fadeDuration: fade,
          curve: Curves.linear,
          style: style,
        );
        expect(span.toPlainText(), text, reason: 'at ${ms}ms');
      }
    });

    test('zero fade duration settles everything', () {
      final span = buildFadeSpan(
        text: text,
        runs: const [FadeRun(0, 11, Duration.zero)],
        now: Duration.zero,
        fadeDuration: Duration.zero,
        curve: Curves.linear,
        style: style,
      ) as TextSpan;
      expect(span.toPlainText(), text);
      expect(span.children, isNull);
    });

    test('run offsets are clamped to the text bounds', () {
      final span = buildFadeSpan(
        text: 'ab',
        runs: const [FadeRun(0, 99, Duration.zero)],
        now: Duration.zero,
        fadeDuration: fade,
        curve: Curves.linear,
        style: style,
      );
      expect(span.toPlainText(), 'ab');
    });
  });

  group('hasActiveFade', () {
    const runs = [FadeRun(6, 11, Duration.zero)];

    test('true while a run is fading', () {
      expect(
        hasActiveFade(runs: runs, now: Duration.zero, fadeDuration: fade),
        isTrue,
      );
      expect(
        hasActiveFade(
          runs: runs,
          now: const Duration(milliseconds: 179),
          fadeDuration: fade,
        ),
        isTrue,
      );
    });

    test('false once every run has settled', () {
      expect(
        hasActiveFade(
          runs: runs,
          now: const Duration(milliseconds: 180),
          fadeDuration: fade,
        ),
        isFalse,
      );
      expect(
        hasActiveFade(runs: const [], now: Duration.zero, fadeDuration: fade),
        isFalse,
      );
    });

    test('false when the fade duration is zero', () {
      expect(
        hasActiveFade(
          runs: runs,
          now: Duration.zero,
          fadeDuration: Duration.zero,
        ),
        isFalse,
      );
    });
  });
}
