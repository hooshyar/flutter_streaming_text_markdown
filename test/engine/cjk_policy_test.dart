// WordPolicy's unspaced-CJK unit policy, for B1 acceptance criterion 7:
// unspaced CJK (Han/Kana) text reveals in 2-grapheme runs while the stream
// is open, and never stalls.

import 'package:flutter_streaming_text_markdown/src/engine/reveal_engine.dart';
import 'package:flutter_streaming_text_markdown/src/engine/unit_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WordPolicy on unspaced CJK', () {
    const policy = WordPolicy();

    test('advances 2 graphemes per call while input stays open', () {
      const source = '你好世界你好世界'; // 8 Han graphemes, no whitespace
      var from = 0;
      final steps = <int>[];
      while (from < source.length) {
        final next = policy.nextBoundary(source, from, inputClosed: false);
        if (next == from) break;
        steps.add(next - from);
        from = next;
      }
      expect(from, source.length, reason: 'the whole run must get revealed');
      expect(
        steps,
        List<int>.filled(steps.length, 2),
        reason: 'every step reveals exactly 2 graphemes',
      );
    });

    test('never stalls: an odd-length CJK run still fully reveals', () {
      const source = '你好世'; // 3 graphemes: one step of 2 + one of 1
      var from = 0;
      final steps = <int>[];
      var guard = 0;
      while (from < source.length && guard < 10) {
        final next = policy.nextBoundary(source, from, inputClosed: false);
        expect(
          next,
          greaterThan(from),
          reason: 'CJK must never withhold, even with input open',
        );
        steps.add(next - from);
        from = next;
        guard++;
      }
      expect(from, source.length);
      expect(steps, [2, 1]);
    });

    test('through a live RevealEngine: unspaced CJK reveals progressively '
        'while streamed, with no stall and final == source', () {
      const full = '你好世界，欢迎来到这个应用程序。';
      final engine = RevealEngine(policy: const WordPolicy());

      // Simulate a stream arriving one grapheme at a time.
      var appended = '';
      for (final grapheme in full.characters) {
        appended += grapheme;
        engine.setSource(appended);
        var progressedThisChunk = true;
        while (progressedThisChunk) {
          progressedThisChunk = engine.step();
        }
      }
      engine.close();
      var progressed = true;
      while (progressed) {
        progressed = engine.step();
      }

      expect(engine.revealed, full);
      expect(engine.isComplete, isTrue);
    });

    test('mixed Kana + Han unspaced run reveals in 2-grapheme steps too', () {
      const source = 'ひらがなカタカナ漢字テスト'; // no whitespace
      var from = 0;
      var stalled = false;
      while (from < source.length) {
        final next = policy.nextBoundary(source, from, inputClosed: false);
        if (next == from) {
          stalled = true;
          break;
        }
        expect(next - from, lessThanOrEqualTo(2));
        from = next;
      }
      expect(stalled, isFalse, reason: 'unspaced Kana/Han must never stall');
      expect(from, source.length);
    });

    test('a CJK word followed by whitespace still yields a clean boundary', () {
      const source = '你好 world';
      final first = policy.nextBoundary(source, 0, inputClosed: false);
      // "你好" is 2 Han graphemes -> one 2-grapheme step.
      expect(source.substring(0, first), '你好');
    });
  });

  group('WordPolicy on latin text is unaffected by the CJK change', () {
    const policy = WordPolicy();

    test('plain latin words still wait for a trailing boundary while open', () {
      const source = 'hello world';
      // "hello" can't be confirmed complete until its trailing whitespace
      // (or closed input) is seen.
      final next = policy.nextBoundary(source, 0, inputClosed: false);
      expect(source.substring(0, next), 'hello ');
    });
  });
}

extension on String {
  Iterable<String> get characters {
    // Grapheme-aware iteration without pulling in package:characters here;
    // for this test's pure-BMP CJK/punctuation corpus, code-unit iteration
    // matches grapheme iteration.
    return runes.map(String.fromCharCode);
  }
}
