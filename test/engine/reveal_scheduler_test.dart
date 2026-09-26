import 'package:fake_async/fake_async.dart';
import 'package:flutter_streaming_text_markdown/src/engine/reveal_engine.dart';
import 'package:flutter_streaming_text_markdown/src/engine/reveal_pacer.dart';
import 'package:flutter_streaming_text_markdown/src/engine/reveal_scheduler.dart';
import 'package:flutter_streaming_text_markdown/src/engine/unit_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RevealScheduler', () {
    test('ticks the engine forward on its own timer', () {
      fakeAsync((async) {
        final engine = RevealEngine(policy: const CharPolicy())
          ..setSource('hello', closed: true);
        final scheduler = RevealScheduler(
          engine: engine,
          interval: const Duration(milliseconds: 10),
        );

        scheduler.start();
        expect(scheduler.isRunning, isTrue);

        async.elapse(const Duration(milliseconds: 10));
        expect(engine.cursor, 1);

        async.elapse(const Duration(milliseconds: 40));
        expect(engine.cursor, 5);
        expect(engine.revealed, 'hello');

        scheduler.dispose();
      });
    });

    test('pause stops ticking and resume continues from the same cursor', () {
      fakeAsync((async) {
        final engine = RevealEngine(policy: const CharPolicy())
          ..setSource('abcdef', closed: true);
        final scheduler = RevealScheduler(
          engine: engine,
          interval: const Duration(milliseconds: 10),
        );
        scheduler.start();

        async.elapse(const Duration(milliseconds: 20));
        expect(engine.cursor, 2);

        scheduler.pause();
        expect(scheduler.isRunning, isFalse);
        async.elapse(const Duration(milliseconds: 100));
        expect(engine.cursor, 2, reason: 'paused: no further ticks');

        scheduler.resume();
        async.elapse(const Duration(milliseconds: 20));
        expect(engine.cursor, 4);

        scheduler.dispose();
      });
    });

    test('changing interval mid-run does not lose position', () {
      fakeAsync((async) {
        final engine = RevealEngine(policy: const CharPolicy())
          ..setSource('abcdefgh', closed: true);
        final scheduler = RevealScheduler(
          engine: engine,
          interval: const Duration(milliseconds: 10),
        );
        scheduler.start();

        async.elapse(const Duration(milliseconds: 30));
        expect(engine.cursor, 3);

        scheduler.interval = const Duration(milliseconds: 5);
        expect(scheduler.interval, const Duration(milliseconds: 5));
        expect(engine.cursor, 3, reason: 'rescheduling must not skip units');

        async.elapse(const Duration(milliseconds: 25));
        expect(engine.cursor, 8);

        scheduler.dispose();
      });
    });

    test('idles with no backlog while input is open, wakes on append', () {
      fakeAsync((async) {
        final engine = RevealEngine(policy: const CharPolicy());
        engine.setSource('ab'); // input stays open
        final scheduler = RevealScheduler(
          engine: engine,
          interval: const Duration(milliseconds: 10),
        );

        scheduler.start();
        async.elapse(const Duration(milliseconds: 30));
        expect(
          engine.revealed,
          'a',
          reason:
              'the final grapheme is withheld while input stays open - '
              'the next chunk might still extend it',
        );
        expect(
          scheduler.isRunning,
          isFalse,
          reason:
              'no further progress is achievable yet: must idle instead of '
              'busy-ticking forever',
        );

        engine.append('cd');
        expect(
          scheduler.isRunning,
          isTrue,
          reason: 'appending must wake an idle scheduler automatically',
        );

        async.elapse(const Duration(milliseconds: 30));
        expect(
          engine.revealed,
          'abc',
          reason: 'only the new final grapheme is withheld this time',
        );
        expect(scheduler.isRunning, isFalse);

        engine.close();
        expect(
          scheduler.isRunning,
          isTrue,
          reason: 'closing releases the withheld tail grapheme',
        );
        async.elapse(const Duration(milliseconds: 10));
        expect(engine.revealed, 'abcd');
        expect(engine.isComplete, isTrue);

        scheduler.dispose();
      });
    });

    test('fires completion exactly once when the stream closes', () {
      fakeAsync((async) {
        var completions = 0;
        final engine = RevealEngine(
          policy: const CharPolicy(),
          onComplete: () => completions++,
        );
        engine.setSource('ab');
        final scheduler = RevealScheduler(
          engine: engine,
          interval: const Duration(milliseconds: 10),
        );
        scheduler.start();

        async.elapse(const Duration(milliseconds: 20));
        expect(completions, 0);

        engine.close();
        async.elapse(const Duration(milliseconds: 10));
        expect(completions, 1);
        expect(engine.isComplete, isTrue);

        async.elapse(const Duration(seconds: 1));
        expect(completions, 1, reason: 'onComplete must not refire');

        scheduler.dispose();
      });
    });

    test('exactly one Timer.periodic is ever active at a time', () {
      fakeAsync((async) {
        final engine = RevealEngine(policy: const CharPolicy())
          ..setSource('abcdefgh', closed: true);
        final scheduler = RevealScheduler(
          engine: engine,
          interval: const Duration(milliseconds: 10),
        );
        scheduler.start();
        scheduler.start(); // idempotent: must not create a second timer
        async.elapse(const Duration(milliseconds: 10));
        expect(async.periodicTimerCount, 1);
        scheduler.dispose();
        expect(async.periodicTimerCount, 0);
      });
    });

    test('a custom RevealPacer controls units revealed per tick', () {
      fakeAsync((async) {
        final engine = RevealEngine(policy: const CharPolicy())
          ..setSource('abcdefgh', closed: true);
        final scheduler = RevealScheduler(
          engine: engine,
          interval: const Duration(milliseconds: 10),
          pacer: const _AlwaysThreePacer(),
        );
        scheduler.start();

        async.elapse(const Duration(milliseconds: 10));
        expect(engine.cursor, 3);

        async.elapse(const Duration(milliseconds: 10));
        expect(engine.cursor, 6);

        scheduler.dispose();
      });
    });
  });
}

class _AlwaysThreePacer extends RevealPacer {
  const _AlwaysThreePacer();
  @override
  int unitsThisTick(int backlogUnits) => 3;
}
