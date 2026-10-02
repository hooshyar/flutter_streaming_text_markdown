// Coverage for lib/src/presets/animation_presets.dart: the LLMAnimationPresets
// static configs, AnimationSpeed.bySpeed, and StreamingTextConfig's
// copyWith/==/hashCode/toString.

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

void main() {
  group('LLMAnimationPresets', () {
    test('chatGPT is fast, character-by-character, with a quick fade', () {
      const c = LLMAnimationPresets.chatGPT;
      expect(c.wordByWord, isFalse);
      expect(c.chunkSize, 1);
      expect(c.fadeInEnabled, isTrue);
      expect(c.typingSpeed, const Duration(milliseconds: 15));
    });

    test('claude is word-by-word with a smoother fade', () {
      const c = LLMAnimationPresets.claude;
      expect(c.wordByWord, isTrue);
      expect(c.fadeInCurve, Curves.easeInOut);
    });

    test('instant shows everything with no fade', () {
      const c = LLMAnimationPresets.instant;
      expect(c.typingSpeed, Duration.zero);
      expect(c.fadeInEnabled, isFalse);
      expect(c.chunkSize, greaterThan(100));
    });

    test('typewriter has no fade but a deliberate pace', () {
      const c = LLMAnimationPresets.typewriter;
      expect(c.fadeInEnabled, isFalse);
      expect(c.wordByWord, isFalse);
    });

    test('gentle uses a longer fade duration', () {
      const c = LLMAnimationPresets.gentle;
      expect(c.fadeInDuration, const Duration(milliseconds: 400));
    });

    test('bouncy uses a bounce curve', () {
      const c = LLMAnimationPresets.bouncy;
      expect(c.fadeInCurve, Curves.bounceOut);
    });

    test('chunks reveals multiple graphemes per tick', () {
      const c = LLMAnimationPresets.chunks;
      expect(c.chunkSize, 3);
      expect(c.wordByWord, isFalse);
    });

    test('rtlOptimized disables fade for RTL performance', () {
      const c = LLMAnimationPresets.rtlOptimized;
      expect(c.fadeInEnabled, isFalse);
      expect(c.wordByWord, isTrue);
    });

    test('professional uses a decelerate curve', () {
      const c = LLMAnimationPresets.professional;
      expect(c.fadeInCurve, Curves.decelerate);
    });

    test(
      'bySpeed returns a distinct, monotonically faster config per speed',
      () {
        final slow = LLMAnimationPresets.bySpeed(AnimationSpeed.slow);
        final medium = LLMAnimationPresets.bySpeed(AnimationSpeed.medium);
        final fast = LLMAnimationPresets.bySpeed(AnimationSpeed.fast);
        final ultraFast = LLMAnimationPresets.bySpeed(AnimationSpeed.ultraFast);

        expect(slow.typingSpeed, greaterThan(medium.typingSpeed));
        expect(medium.typingSpeed, greaterThan(fast.typingSpeed));
        expect(fast.typingSpeed, greaterThan(ultraFast.typingSpeed));
        expect(ultraFast.fadeInEnabled, isFalse);
      },
    );
  });

  group('StreamingTextConfig', () {
    const base = StreamingTextConfig(
      typingSpeed: Duration(milliseconds: 50),
      wordByWord: false,
      chunkSize: 1,
      fadeInEnabled: true,
      fadeInDuration: Duration(milliseconds: 100),
      fadeInCurve: Curves.linear,
    );

    test('copyWith overrides only the given fields', () {
      final updated = base.copyWith(chunkSize: 5, wordByWord: true);

      expect(updated.chunkSize, 5);
      expect(updated.wordByWord, isTrue);
      expect(updated.typingSpeed, base.typingSpeed);
      expect(updated.fadeInCurve, base.fadeInCurve);
    });

    test('== and hashCode are structural', () {
      const other = StreamingTextConfig(
        typingSpeed: Duration(milliseconds: 50),
        wordByWord: false,
        chunkSize: 1,
        fadeInEnabled: true,
        fadeInDuration: Duration(milliseconds: 100),
        fadeInCurve: Curves.linear,
      );

      expect(base, equals(other));
      expect(base.hashCode, other.hashCode);
      expect(base, isNot(equals(base.copyWith(chunkSize: 2))));
    });

    test('toString reports every field', () {
      final s = base.toString();
      expect(s, contains('typingSpeed'));
      expect(s, contains('wordByWord'));
      expect(s, contains('chunkSize'));
      expect(s, contains('fadeInEnabled'));
      expect(s, contains('fadeInDuration'));
      expect(s, contains('fadeInCurve'));
    });
  });
}
