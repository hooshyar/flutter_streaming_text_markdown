// Coverage for the deprecated StreamProvider / DefaultStreamProvider path
// (lib/src/streaming/stream_provider.dart,
// lib/src/streaming/default_stream_provider.dart). Neither is wired to any
// widget — StreamingTextMarkdown.stream is the supported way to stream text
// — but the deprecated API is still public and shipped, so it's exercised
// here rather than left completely uncovered.
// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

void main() {
  group('StreamData factories', () {
    test('text() carries content and metadata', () {
      final data = StreamData.text('hello', metadata: {'a': 1});
      expect(data.type, StreamDataType.text);
      expect(data.content, 'hello');
      expect(data.metadata, {'a': 1});
    });

    test('toolCall() carries a map payload', () {
      final data = StreamData.toolCall({'name': 'lookup'});
      expect(data.type, StreamDataType.toolCall);
      expect(data.content, {'name': 'lookup'});
    });

    test('error() carries the error string', () {
      final data = StreamData.error('boom');
      expect(data.type, StreamDataType.error);
      expect(data.content, 'boom');
    });

    test('completion() has no content', () {
      final data = StreamData.completion();
      expect(data.type, StreamDataType.completion);
      expect(data.content, isNull);
    });
  });

  group('StreamConfig', () {
    test('has sensible documented defaults', () {
      const config = StreamConfig();
      expect(config.maxChunkSize, 10);
      expect(config.chunkDelay, 50);
      expect(config.includeMetadata, isTrue);
      expect(config.retryAttempts, 3);
      expect(config.retryDelay, const Duration(seconds: 1));
      expect(config.timeoutDuration, const Duration(seconds: 30));
      expect(config.options, isNull);
    });
  });

  group('StreamException', () {
    test('toString includes the code and message', () {
      const e = StreamException('bad input', code: 'BAD');
      expect(e.toString(), 'StreamException(BAD): bad input');
      expect(e.message, 'bad input');
      expect(e.code, 'BAD');
    });

    test('defaults to STREAM_ERROR code', () {
      const e = StreamException('oops');
      expect(e.code, 'STREAM_ERROR');
    });
  });

  group('DefaultStreamProvider', () {
    test('streams input as chunks and completes', () {
      fakeAsync((async) {
        final provider = DefaultStreamProvider(
          config: const StreamConfig(
            maxChunkSize: 3,
            chunkDelay: 10,
            includeMetadata: true,
          ),
        );

        final events = <StreamData>[];
        provider.startStream('Hello World').listen(events.add);

        async.elapse(const Duration(seconds: 2));

        expect(events.any((e) => e.type == StreamDataType.completion), isTrue);
        final textChunks =
            events
                .where((e) => e.type == StreamDataType.text)
                .map((e) => e.content as String)
                .where((c) => c.isNotEmpty)
                .join();
        expect(textChunks, 'Hello World');

        provider.dispose();
        async.flushMicrotasks();
      });
    });

    test('throws if a stream is already in progress', () {
      fakeAsync((async) {
        final provider = DefaultStreamProvider(
          config: const StreamConfig(chunkDelay: 5),
        );
        provider.startStream('abc').listen((_) {});

        expect(
          () => provider.startStream('def'),
          throwsA(isA<StreamException>()),
        );

        async.elapse(const Duration(seconds: 1));
        provider.dispose();
        async.flushMicrotasks();
      });
    });

    test('pause/resume toggles isPaused and emits status metadata', () {
      fakeAsync((async) {
        final provider = DefaultStreamProvider(
          config: const StreamConfig(
            maxChunkSize: 2,
            chunkDelay: 5,
            includeMetadata: true,
          ),
        );

        final events = <StreamData>[];
        provider.startStream('abcdef').listen(events.add);

        expect(provider.isPaused, isFalse);
        provider.pauseStream();
        expect(provider.isPaused, isTrue);

        async.elapse(const Duration(milliseconds: 200));

        provider.resumeStream();
        expect(provider.isPaused, isFalse);

        async.elapse(const Duration(seconds: 2));

        expect(
          events.any(
            (e) =>
                e.type == StreamDataType.text &&
                (e.metadata?['status'] == 'paused'),
          ),
          isTrue,
        );
        expect(
          events.any(
            (e) =>
                e.type == StreamDataType.text &&
                (e.metadata?['status'] == 'resumed'),
          ),
          isTrue,
        );

        provider.dispose();
        async.flushMicrotasks();
      });
    });

    test('stopStream closes the controller and emits a stopped status', () {
      fakeAsync((async) {
        final provider = DefaultStreamProvider(
          config: const StreamConfig(
            maxChunkSize: 2,
            chunkDelay: 500,
            includeMetadata: true,
          ),
        );

        final events = <StreamData>[];
        provider.startStream('abcdef').listen(events.add);

        async.elapse(const Duration(milliseconds: 10));
        provider.stopStream();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        expect(
          events.any(
            (e) =>
                e.type == StreamDataType.text &&
                e.metadata?['status'] == 'stopped',
          ),
          isTrue,
          reason: 'stopStream should emit a stopped status event',
        );
        // Only the 'stopped' status marker should have been emitted — the
        // chunk delay (500ms) never elapsed before stop, so no content
        // chunks or the completion event should follow.
        expect(events.any((e) => e.type == StreamDataType.completion), isFalse);

        provider.dispose();
        async.flushMicrotasks();
      });
    });

    test('dispose() is safe to call when no stream was started', () {
      fakeAsync((async) {
        final provider = DefaultStreamProvider();
        expect(() => provider.dispose(), returnsNormally);
        async.flushMicrotasks();
      });
    });

    test('initialize() disposes any prior stream state', () {
      fakeAsync((async) {
        final provider = DefaultStreamProvider(
          config: const StreamConfig(chunkDelay: 5),
        );
        provider.startStream('abc').listen((_) {});
        async.elapse(const Duration(milliseconds: 5));

        expect(() => provider.initialize(), returnsNormally);
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
      });
    });

    // Stream.timeout()'s internal Timer doesn't interact reliably with
    // fake_async's virtual clock, so this one exercises the real clock —
    // durations are kept small (well under the suite's 60s per-test
    // timeout) so it stays fast.
    test('a stream that times out emits a STREAM_TIMEOUT error', () async {
      // A chunk delay far longer than the timeout means no data arrives
      // before .timeout() gives up and injects the STREAM_TIMEOUT error.
      final provider = DefaultStreamProvider(
        config: const StreamConfig(
          maxChunkSize: 1,
          chunkDelay: 10000,
          timeoutDuration: Duration(milliseconds: 20),
          includeMetadata: false,
        ),
      );

      final errorCompleter = Completer<Object>();
      provider
          .startStream('abc')
          .listen(
            (_) {},
            onError: (Object e) {
              if (!errorCompleter.isCompleted) errorCompleter.complete(e);
            },
            cancelOnError: true,
          );

      final sawError = await errorCompleter.future.timeout(
        const Duration(seconds: 5),
      );

      expect(sawError, isA<StreamException>());
      expect((sawError as StreamException).code, 'STREAM_TIMEOUT');

      await provider.dispose();
    });
  });
}
