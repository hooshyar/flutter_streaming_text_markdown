import 'dart:async';
import 'package:characters/characters.dart';
import 'stream_provider.dart';

// ignore_for_file: deprecated_member_use_from_same_package

/// A professional default implementation of [StreamProvider].
@Deprecated(
  'Not wired to any widget; pass a Stream<String> to '
  'StreamingTextMarkdown.stream. Removed in 2.0.',
)
class DefaultStreamProvider implements StreamProvider {
  /// The current stream controller.
  StreamController<StreamData>? _controller;

  /// The current stream subscription.
  StreamSubscription<StreamData>? _subscription;

  /// The configuration for this provider.
  final StreamConfig config;

  /// Whether the stream is currently paused.
  bool _isPaused = false;

  /// Current retry attempt count.
  int _retryCount = 0;

  /// Whether the stream is currently paused.
  bool get isPaused => _isPaused;

  /// Creates a new [DefaultStreamProvider] instance.
  DefaultStreamProvider({StreamConfig? config})
    : config = config ?? const StreamConfig();

  @override
  Future<void> initialize() async {
    await dispose();
  }

  @override
  Stream<StreamData> startStream(String input) {
    if (_controller != null) {
      throw const StreamException(
        'Stream already in progress',
        code: 'STREAM_ALREADY_STARTED',
      );
    }

    _controller = StreamController<StreamData>();
    _retryCount = 0;

    // Start processing in the background
    _processStream(input).catchError((error) {
      _handleError(error);
    });

    return _controller!.stream.timeout(
      config.timeoutDuration,
      onTimeout: (sink) {
        sink.addError(
          const StreamException('Stream timeout', code: 'STREAM_TIMEOUT'),
        );
        sink.close();
      },
    );
  }

  /// Handles a stream processing error, retrying up to
  /// [StreamConfig.retryAttempts] times before giving up.
  ///
  /// KNOWN BROKEN (not fixed here — this whole provider is deprecated):
  /// the retry re-invokes [_processStream] on [_lastInput], the *entire*
  /// original input, from the top — it does not resume from the chunk that
  /// failed, so a retry re-emits everything already streamed. It also
  /// races the `finally` block in [_processStream], which nulls out
  /// [_controller] on every exit, including the one that's about to retry.
  void _handleError(dynamic error) {
    if (_controller == null || _controller!.isClosed) return;

    if (_retryCount < config.retryAttempts) {
      _retryCount++;
      _controller!.add(
        StreamData.error(
          'Error: ${error.toString()}. Retrying... (Attempt $_retryCount/${config.retryAttempts})',
        ),
      );
      Future.delayed(config.retryDelay, () {
        // Retry the stream
        _processStream(_lastInput!).catchError(_handleError);
      });
    } else {
      _controller!.addError(error);
      _controller!.close();
    }
  }

  String? _lastInput;

  /// Processes the input and adds it to the stream.
  Future<void> _processStream(String input) async {
    _lastInput = input;
    try {
      if (config.includeMetadata &&
          _controller != null &&
          !_controller!.isClosed) {
        _controller!.add(
          StreamData.text(
            '',
            metadata: {
              'timestamp': DateTime.now().toIso8601String(),
              'chunkSize': config.maxChunkSize,
              'totalLength': input.length,
            },
          ),
        );
      }

      // Process the input in chunks
      final chunks = _processIntoChunks(input);
      int processedChunks = 0;

      for (final chunk in chunks) {
        if (_controller == null || _controller!.isClosed) break;

        if (_isPaused) {
          await _waitForResume();
        }

        // Add a delay between chunks for natural typing effect
        await Future.delayed(Duration(milliseconds: config.chunkDelay));

        if (_controller != null && !_controller!.isClosed) {
          _controller!.add(
            StreamData.text(
              chunk,
              metadata:
                  config.includeMetadata && processedChunks % 10 == 0
                      ? {
                        'progress': processedChunks / chunks.length,
                        'processedChunks': processedChunks,
                        'totalChunks': chunks.length,
                      }
                      : null,
            ),
          );
          processedChunks++;
        }
      }

      // Signal completion if controller is still open
      if (_controller != null && !_controller!.isClosed) {
        if (config.includeMetadata) {
          _controller!.add(
            StreamData.text(
              '',
              metadata: {
                'status': 'complete',
                'timestamp': DateTime.now().toIso8601String(),
              },
            ),
          );
        }
        _controller!.add(StreamData.completion());
      }
    } catch (e) {
      throw StreamException(e.toString(), code: 'STREAM_PROCESSING_ERROR');
    } finally {
      if (_controller != null && !_controller!.isClosed) {
        await _controller!.close();
      }
      _controller = null;
    }
  }

  @override
  Future<void> pauseStream() async {
    _isPaused = true;
    if (config.includeMetadata &&
        _controller != null &&
        !_controller!.isClosed) {
      _controller!.add(StreamData.text('', metadata: {'status': 'paused'}));
    }
  }

  @override
  Future<void> resumeStream() async {
    _isPaused = false;
    if (config.includeMetadata &&
        _controller != null &&
        !_controller!.isClosed) {
      _controller!.add(StreamData.text('', metadata: {'status': 'resumed'}));
    }
  }

  @override
  Future<void> stopStream() async {
    if (_controller != null && !_controller!.isClosed) {
      if (config.includeMetadata) {
        _controller!.add(StreamData.text('', metadata: {'status': 'stopped'}));
      }
      await _controller!.close();
    }
    _controller = null;
  }

  @override
  Future<void> dispose() async {
    await stopStream();
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Processes the input text into chunks.
  List<String> _processIntoChunks(String input) {
    final chunks = <String>[];
    final chars = input.characters;

    for (var i = 0; i < chars.length; i += config.maxChunkSize) {
      final end =
          (i + config.maxChunkSize < chars.length)
              ? i + config.maxChunkSize
              : chars.length;
      chunks.add(chars.getRange(i, end).toString());
    }

    return chunks;
  }

  /// Waits for the stream to be resumed.
  Future<void> _waitForResume() async {
    while (_isPaused) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
}
