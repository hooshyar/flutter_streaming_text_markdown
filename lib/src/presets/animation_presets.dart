import 'package:flutter/material.dart';

/// Animation presets optimized for LLM text streaming.
/// 
/// These presets provide out-of-the-box configurations for common
/// LLM use cases like ChatGPT-style streaming, Claude-style responses,
/// and various chat interface patterns.
class LLMAnimationPresets {
  /// ChatGPT-style streaming with fast character-by-character animation
  static const StreamingTextConfig chatGPT = StreamingTextConfig(
    typingSpeed: Duration(milliseconds: 15),
    wordByWord: false,
    chunkSize: 1,
    fadeInEnabled: true,
    fadeInDuration: Duration(milliseconds: 150),
    fadeInCurve: Curves.easeOut,
  );
  
  /// Claude-style streaming with smooth word-by-word animation
  static const StreamingTextConfig claude = StreamingTextConfig(
    typingSpeed: Duration(milliseconds: 80),
    wordByWord: true,
    chunkSize: 1,
    fadeInEnabled: true,
    fadeInDuration: Duration(milliseconds: 200),
    fadeInCurve: Curves.easeInOut,
  );
  
  /// Instant display for when speed is priority
  static const StreamingTextConfig instant = StreamingTextConfig(
    typingSpeed: Duration.zero,
    wordByWord: false,
    chunkSize: 1000, // Large chunk to show everything at once
    fadeInEnabled: false,
    fadeInDuration: Duration.zero,
    fadeInCurve: Curves.linear,
  );
  
  /// Smooth typewriter effect for dramatic presentations
  static const StreamingTextConfig typewriter = StreamingTextConfig(
    typingSpeed: Duration(milliseconds: 50),
    wordByWord: false,
    chunkSize: 1,
    fadeInEnabled: false,
    fadeInDuration: Duration.zero,
    fadeInCurve: Curves.linear,
  );
  
  /// Gentle fade-in effect for subtle animations
  static const StreamingTextConfig gentle = StreamingTextConfig(
    typingSpeed: Duration(milliseconds: 100),
    wordByWord: true,
    chunkSize: 1,
    fadeInEnabled: true,
    fadeInDuration: Duration(milliseconds: 400),
    fadeInCurve: Curves.easeInOut,
  );
  
  /// Bouncy animation for playful interfaces
  static const StreamingTextConfig bouncy = StreamingTextConfig(
    typingSpeed: Duration(milliseconds: 60),
    wordByWord: true,
    chunkSize: 1,
    fadeInEnabled: true,
    fadeInDuration: Duration(milliseconds: 300),
    fadeInCurve: Curves.bounceOut,
  );
  
  /// Fast chunk-based streaming for long content
  static const StreamingTextConfig chunks = StreamingTextConfig(
    typingSpeed: Duration(milliseconds: 30),
    wordByWord: false,
    chunkSize: 3,
    fadeInEnabled: true,
    fadeInDuration: Duration(milliseconds: 100),
    fadeInCurve: Curves.easeOut,
  );
  
  /// Optimized for RTL languages like Arabic
  static const StreamingTextConfig rtlOptimized = StreamingTextConfig(
    typingSpeed: Duration(milliseconds: 100),
    wordByWord: true,
    chunkSize: 1,
    fadeInEnabled: false, // Disabled for better RTL performance
    fadeInDuration: Duration.zero,
    fadeInCurve: Curves.linear,
  );
  
  /// Professional presentation style
  static const StreamingTextConfig professional = StreamingTextConfig(
    typingSpeed: Duration(milliseconds: 40),
    wordByWord: true,
    chunkSize: 1,
    fadeInEnabled: true,
    fadeInDuration: Duration(milliseconds: 250),
    fadeInCurve: Curves.decelerate,
  );
  
  /// Creates a custom config based on speed preference
  static StreamingTextConfig bySpeed(AnimationSpeed speed) {
    switch (speed) {
      case AnimationSpeed.slow:
        return const StreamingTextConfig(
          typingSpeed: Duration(milliseconds: 150),
          wordByWord: true,
          chunkSize: 1,
          fadeInEnabled: true,
          fadeInDuration: Duration(milliseconds: 400),
          fadeInCurve: Curves.easeInOut,
        );
      case AnimationSpeed.medium:
        return const StreamingTextConfig(
          typingSpeed: Duration(milliseconds: 80),
          wordByWord: true,
          chunkSize: 1,
          fadeInEnabled: true,
          fadeInDuration: Duration(milliseconds: 200),
          fadeInCurve: Curves.easeOut,
        );
      case AnimationSpeed.fast:
        return const StreamingTextConfig(
          typingSpeed: Duration(milliseconds: 30),
          wordByWord: false,
          chunkSize: 2,
          fadeInEnabled: true,
          fadeInDuration: Duration(milliseconds: 100),
          fadeInCurve: Curves.easeOut,
        );
      case AnimationSpeed.ultraFast:
        return const StreamingTextConfig(
          typingSpeed: Duration(milliseconds: 10),
          wordByWord: false,
          chunkSize: 3,
          fadeInEnabled: false,
          fadeInDuration: Duration.zero,
          fadeInCurve: Curves.linear,
        );
    }
  }
}

/// Speed presets for quick configuration
enum AnimationSpeed {
  slow,
  medium,
  fast,
  ultraFast,
}

/// Configuration class for streaming text animations
class StreamingTextConfig {
  final Duration typingSpeed;
  final bool wordByWord;
  final int chunkSize;
  final bool fadeInEnabled;
  final Duration fadeInDuration;
  final Curve fadeInCurve;
  
  const StreamingTextConfig({
    required this.typingSpeed,
    required this.wordByWord,
    required this.chunkSize,
    required this.fadeInEnabled,
    required this.fadeInDuration,
    required this.fadeInCurve,
  });
  
  /// Creates a copy with modified parameters
  StreamingTextConfig copyWith({
    Duration? typingSpeed,
    bool? wordByWord,
    int? chunkSize,
    bool? fadeInEnabled,
    Duration? fadeInDuration,
    Curve? fadeInCurve,
  }) {
    return StreamingTextConfig(
      typingSpeed: typingSpeed ?? this.typingSpeed,
      wordByWord: wordByWord ?? this.wordByWord,
      chunkSize: chunkSize ?? this.chunkSize,
      fadeInEnabled: fadeInEnabled ?? this.fadeInEnabled,
      fadeInDuration: fadeInDuration ?? this.fadeInDuration,
      fadeInCurve: fadeInCurve ?? this.fadeInCurve,
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StreamingTextConfig &&
        other.typingSpeed == typingSpeed &&
        other.wordByWord == wordByWord &&
        other.chunkSize == chunkSize &&
        other.fadeInEnabled == fadeInEnabled &&
        other.fadeInDuration == fadeInDuration &&
        other.fadeInCurve == fadeInCurve;
  }
  
  @override
  int get hashCode {
    return Object.hash(
      typingSpeed,
      wordByWord,
      chunkSize,
      fadeInEnabled,
      fadeInDuration,
      fadeInCurve,
    );
  }
  
  @override
  String toString() {
    return 'StreamingTextConfig('
        'typingSpeed: $typingSpeed, '
        'wordByWord: $wordByWord, '
        'chunkSize: $chunkSize, '
        'fadeInEnabled: $fadeInEnabled, '
        'fadeInDuration: $fadeInDuration, '
        'fadeInCurve: $fadeInCurve)';
  }
}