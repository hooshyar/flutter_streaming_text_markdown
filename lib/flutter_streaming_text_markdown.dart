/// A Flutter package for displaying streaming text with Markdown support.
///
/// This package provides widgets for creating animated text displays with
/// markdown formatting. It's perfect for creating typing animations,
/// chat interfaces, or any text that needs to appear gradually with style.
///
/// The main widget is [StreamingTextMarkdown], which combines markdown
/// rendering with customizable typing animations.
///
/// Example usage:
/// ```dart
/// StreamingTextMarkdown(
///   text: '''# Welcome! 👋
///   This is a **demo** of streaming text with *markdown* support.''',
///   typingSpeed: Duration(milliseconds: 50),
///   fadeInEnabled: true,
/// )
/// ```
library flutter_streaming_text_markdown;

export 'src/streaming/streaming.dart';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'src/streaming/streaming_text.dart';

/// A widget that displays streaming text with Markdown support.
///
/// This widget combines the power of markdown rendering with smooth
/// typing animations. It supports:
/// * Markdown formatting (headers, bold, italic, lists)
/// * Character-by-character or word-by-word typing
/// * Customizable typing speed and animations
/// * RTL language support
/// * Auto-scrolling
///
/// The [text] parameter is required and should contain the markdown-formatted
/// text to be displayed. Use [typingSpeed] to control how fast the text appears,
/// and [wordByWord] to choose between character-by-character or word-by-word animation.
class StreamingTextMarkdown extends StatefulWidget {
  /// The text to display
  final String text;

  /// Initial text to display before the animation starts
  final String initialText;

  /// Markdown style sheet configuration
  final MarkdownStyleSheet? styleSheet;

  /// Padding around the text
  final EdgeInsets padding;

  /// Whether to scroll automatically as new text arrives
  final bool autoScroll;

  /// Whether to enable fade-in animation for each character
  final bool fadeInEnabled;

  /// Duration of the fade-in animation
  final Duration fadeInDuration;

  /// Whether to stream text word by word instead of character by character
  final bool wordByWord;

  /// The number of characters to reveal at once when not in word-by-word mode
  final int chunkSize;

  /// The speed at which each character or word appears
  final Duration typingSpeed;

  /// The text direction
  final TextDirection? textDirection;

  /// The text alignment
  final TextAlign? textAlign;

  const StreamingTextMarkdown({
    super.key,
    required this.text,
    this.initialText = '',
    this.styleSheet,
    this.padding = const EdgeInsets.all(16.0),
    this.autoScroll = true,
    this.fadeInEnabled = false,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.wordByWord = false,
    this.chunkSize = 1,
    this.typingSpeed = const Duration(milliseconds: 50),
    this.textDirection,
    this.textAlign,
  });

  @override
  State<StreamingTextMarkdown> createState() => _StreamingTextMarkdownState();
}

class _StreamingTextMarkdownState extends State<StreamingTextMarkdown> {
  final ScrollController _scrollController = ScrollController();
  TextStyle? _textStyle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache the text style when dependencies change
    _textStyle = Theme.of(context).textTheme.bodyLarge;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Padding(
        padding: widget.padding,
        child: StreamingText(
          key: ValueKey(
              '${widget.text}_${widget.wordByWord}_${widget.chunkSize}_${widget.typingSpeed.inMilliseconds}'),
          text: widget.text,
          style: _textStyle,
          markdownEnabled: true,
          fadeInEnabled: widget.fadeInEnabled,
          fadeInDuration: widget.fadeInDuration,
          wordByWord: widget.wordByWord,
          chunkSize: widget.chunkSize,
          typingSpeed: widget.typingSpeed,
          textDirection: widget.textDirection,
          textAlign: widget.textAlign,
          onComplete: () {
            if (mounted && widget.autoScroll && _scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          },
        ),
      ),
    );
  }
}
