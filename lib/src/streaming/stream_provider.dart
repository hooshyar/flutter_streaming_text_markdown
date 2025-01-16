import 'dart:async';

/// A professional interface for handling streaming data in AI applications.
///
/// This provider manages the streaming of text, tool calls, and other data
/// from AI models in a clean, efficient manner.
abstract class StreamProvider {
  /// Initializes the stream with optional configuration.
  Future<void> initialize();

  /// Starts streaming data with the given input.
  ///
  /// Returns a stream of [StreamData] that can include text, tool calls,
  /// or other structured data.
  Stream<StreamData> startStream(String input);

  /// Pauses the current stream.
  Future<void> pauseStream();

  /// Resumes a paused stream.
  Future<void> resumeStream();

  /// Stops the current stream and cleans up resources.
  Future<void> stopStream();

  /// Disposes of the provider and releases resources.
  Future<void> dispose();
}

/// Professional representation of streaming data.
class StreamData {
  /// The type of data being streamed.
  final StreamDataType type;

  /// The actual content of the stream.
  final dynamic content;

  /// Optional metadata associated with the stream.
  final Map<String, dynamic>? metadata;

  /// Creates a new [StreamData] instance.
  const StreamData({
    required this.type,
    required this.content,
    this.metadata,
  });

  /// Creates a text stream data instance.
  factory StreamData.text(String text, {Map<String, dynamic>? metadata}) {
    return StreamData(
      type: StreamDataType.text,
      content: text,
      metadata: metadata,
    );
  }

  /// Creates a tool call stream data instance.
  factory StreamData.toolCall(Map<String, dynamic> toolCall,
      {Map<String, dynamic>? metadata}) {
    return StreamData(
      type: StreamDataType.toolCall,
      content: toolCall,
      metadata: metadata,
    );
  }

  /// Creates an error stream data instance.
  factory StreamData.error(String error, {Map<String, dynamic>? metadata}) {
    return StreamData(
      type: StreamDataType.error,
      content: error,
      metadata: metadata,
    );
  }

  /// Creates a completion stream data instance.
  factory StreamData.completion({Map<String, dynamic>? metadata}) {
    return StreamData(
      type: StreamDataType.completion,
      content: null,
      metadata: metadata,
    );
  }
}

/// Professional enumeration of stream data types.
enum StreamDataType {
  /// Regular text content
  text,

  /// Tool call data
  toolCall,

  /// Error information
  error,

  /// Stream completion marker
  completion,
}

/// Professional configuration for stream providers.
class StreamConfig {
  /// The maximum chunk size for text streaming.
  final int maxChunkSize;

  /// The delay between chunks in milliseconds.
  final int chunkDelay;

  /// Whether to include metadata in the stream.
  final bool includeMetadata;

  /// Number of retry attempts for failed streams.
  final int retryAttempts;

  /// Delay between retry attempts.
  final Duration retryDelay;

  /// Timeout duration for the stream.
  final Duration timeoutDuration;

  /// Custom configuration options.
  final Map<String, dynamic>? options;

  /// Creates a new [StreamConfig] instance.
  const StreamConfig({
    this.maxChunkSize = 10,
    this.chunkDelay = 50,
    this.includeMetadata = true,
    this.retryAttempts = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.timeoutDuration = const Duration(seconds: 30),
    this.options,
  });
}

/// Professional exception class for stream-related errors.
class StreamException implements Exception {
  /// The error message.
  final String message;

  /// The error code.
  final String code;

  /// Optional error details.
  final Map<String, dynamic>? details;

  /// Creates a new [StreamException] instance.
  const StreamException(
    this.message, {
    this.code = 'STREAM_ERROR',
    this.details,
  });

  @override
  String toString() => 'StreamException($code): $message';
}
