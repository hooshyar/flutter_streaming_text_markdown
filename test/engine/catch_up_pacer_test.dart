// CatchUpPacer coverage for B1 acceptance criterion 6: a backlog-
// proportional pacer that catches up fast on a burst, holds a floor rate,
// bounds backlog under steady input, and drains within a fixed deadline
// after the engine's input closes - while leaving FixedPacer's own
// behaviour (already covered by reveal_scheduler_test.dart) untouched.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_streaming_text_markdown/src/engine/reveal_engine.dart';
import 'package:flutter_streaming_text_markdown/src/engine/reveal_pacer.dart';
import 'package:flutter_streaming_text_markdown/src/engine/reveal_scheduler.dart';
import 'package:flutter_streaming_text_markdown/src/engine/unit_policy.dart';
import 'package:flutter_test/flutter_test.dart';

const _window = Duration(milliseconds: 50);

/// A [RevealScheduler] clock backed by [async]'s own virtual time, so
/// "time since input closed" tracking (used by [CatchUpPacer]'s drain
/// deadline) advances with `async.elapse` instead of real wall-clock time
/// (which `fake_async` does not intercept for a raw `DateTime.now`).
DateTime Function() _fakeClock(FakeAsync async) {
  return () => DateTime.fromMicrosecondsSinceEpoch(async.elapsed.inMicroseconds);
}

void main() {
  group('CatchUpPacer', () {
    test(
      'a 400-char burst, closed immediately, is fully revealed within 1.0s '
      'and the first window reveals less than 50% of it',
      () {
        fakeAsync((async) {
          final engine = RevealEngine(policy: const CharPolicy())
            ..setSource('a' * 400, closed: true);
          final scheduler = RevealScheduler(
            engine: engine,
            interval: _window,
            pacer: const CatchUpPacer(),
            clock: _fakeClock(async),
          );
          scheduler.start();

          async.elapse(_window);
          expect(
            engine.cursor,
            lessThan(200),
            reason: 'first window must not dump more than half the burst',
          );

          async.elapse(const Duration(milliseconds: 950));
          expect(
            engine.revealed,
            'a' * 400,
            reason: 'the whole burst must be gone within 1.0s total',
          );
          expect(engine.isComplete, isTrue);

          scheduler.dispose();
        });
      },
    );

    test(
      'with steady input, backlog never exceeds ~400ms of input plus one '
      'word',
      () {
        fakeAsync((async) {
          final engine = RevealEngine(policy: const WordPolicy());
          final scheduler = RevealScheduler(
            engine: engine,
            interval: _window,
            pacer: const CatchUpPacer(),
            clock: _fakeClock(async),
          );
          scheduler.start();

          // Steady input: append one word (~6 chars incl. space) every
          // 20ms, i.e. ~300 chars/sec, for 2 seconds.
          const chunk = 'word12 ';
          const chunkInterval = Duration(milliseconds: 20);
          final inputCharsPerMs = chunk.length / chunkInterval.inMilliseconds;
          const totalTicks = 100; // 2s / 20ms
          for (var i = 0; i < totalTicks; i++) {
            engine.append(chunk);
            async.elapse(chunkInterval);
            final backlog = engine.source.length - engine.cursor;
            final maxAllowed =
                (400 * inputCharsPerMs).ceil() + chunk.length + 1;
            expect(
              backlog,
              lessThanOrEqualTo(maxAllowed),
              reason: 'backlog grew unbounded under steady input',
            );
          }

          engine.close();
          async.elapse(const Duration(milliseconds: 500));
          expect(engine.revealed, engine.source);
          scheduler.dispose();
        });
      },
    );

    test(
      'decide() never falls under a 30 chars/s floor while backlog > 0, '
      'even when the proportional (k) share alone would',
      () {
        const pacer = CatchUpPacer();
        // Small backlogs are exactly where `ceil(backlog * k)` alone drops
        // under the floor (k = 0.16 needs backlog >= ~10 to clear a 30
        // chars/s floor on a 50ms window unaided) - so this is the case
        // the floor exists to rescue.
        for (final backlog in <int>[1, 2, 3, 4, 5, 6, 8, 10, 12]) {
          final decision = pacer.decide(
            PaceContext(backlog: backlog, interval: _window, inputClosed: false),
          );
          if (decision.minChars >= backlog) {
            // The whole backlog is cleared this tick anyway - trivially at
            // least as fast as any floor could require.
            continue;
          }
          final impliedCharsPerSecond =
              decision.minChars * (1000 / _window.inMilliseconds);
          expect(
            impliedCharsPerSecond,
            greaterThanOrEqualTo(30),
            reason: 'backlog=$backlog must still clear the 30 chars/s floor',
          );
        }
      },
    );

    test(
      'the floor also holds end-to-end once the engine actually drains a '
      'small, closed backlog',
      () {
        fakeAsync((async) {
          final engine = RevealEngine(policy: const CharPolicy())
            ..setSource('b' * 10, closed: true);
          final scheduler = RevealScheduler(
            engine: engine,
            interval: _window,
            pacer: const CatchUpPacer(),
            clock: _fakeClock(async),
          );
          scheduler.start();

          // At >= 30 chars/s a 10-char backlog can't take longer than
          // ~334ms; give it a comfortable margin.
          async.elapse(const Duration(milliseconds: 500));
          expect(engine.revealed, 'b' * 10);
          expect(engine.isComplete, isTrue);

          scheduler.dispose();
        });
      },
    );

    test(
      'any backlog, including 20k, drains within 400ms plus one window '
      'after close',
      () {
        fakeAsync((async) {
          final engine = RevealEngine(policy: const CharPolicy())
            ..setSource('c' * 20000, closed: true);
          final scheduler = RevealScheduler(
            engine: engine,
            interval: _window,
            pacer: const CatchUpPacer(),
            clock: _fakeClock(async),
          );
          scheduler.start();

          async.elapse(const Duration(milliseconds: 450));
          expect(engine.isComplete, isTrue);
          expect(engine.revealed, engine.source);

          scheduler.dispose();
        });
      },
    );

    test('FixedPacer behaviour is unchanged', () {
      fakeAsync((async) {
        final engine = RevealEngine(policy: const CharPolicy())
          ..setSource('abcdefgh', closed: true);
        final scheduler = RevealScheduler(
          engine: engine,
          interval: const Duration(milliseconds: 10),
        ); // default pacer: FixedPacer
        scheduler.start();

        async.elapse(const Duration(milliseconds: 10));
        expect(engine.cursor, 1);
        async.elapse(const Duration(milliseconds: 30));
        expect(engine.cursor, 4);

        scheduler.dispose();
      });
    });
  });
}
