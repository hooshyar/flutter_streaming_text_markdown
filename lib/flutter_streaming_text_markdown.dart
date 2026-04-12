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
library;

export 'src/streaming/streaming.dart';
export 'src/theme/streaming_text_theme.dart';
export 'src/controller/streaming_text_controller.dart';
export 'src/presets/animation_presets.dart';
import 'package:flutter/material.dart';
import 'src/streaming/streaming_text.dart';
import 'src/theme/streaming_text_theme.dart';
import 'src/controller/streaming_text_controller.dart';
import 'src/presets/animation_presets.dart';
import 'src/widgets/streaming_shimmer.dart';

/// A widget that displays streaming text with Markdown support.
///
/// This widget combines the power of markdown rendering with smooth
/// typing animations. It supports:
/// * Markdown formatting (headers, bold, italic, lists)
/// * Character-by-character or word-by-word typing
/// * Customizable typing speed and animations
/// * RTL language support
/// * Auto-scrolling
/// * Theme support through [StreamingTextTheme]
///
/// The [text] parameter is required and should contain the markdown-formatted
/// text to be displayed. Use [typingSpeed] to control how fast the text appears,
/// and [wordByWord] to choose between character-by-character or word-by-word animation.
class StreamingTextMarkdown extends StatefulWidget {
  /// The text to display
  final String text;

  /// Initial text to display before the animation starts
  final String initialText;

  /// Markdown style configuration (TextStyle applied to the markdown renderer)
  final TextStyle? styleSheet;

  /// Custom theme for the widget
  final StreamingTextTheme? theme;

  /// Padding around the text
  final EdgeInsets? padding;

  /// Whether to scroll automatically as new text arrives
  final bool autoScroll;

  /// Whether to enable fade-in animation for each character
  final bool fadeInEnabled;

  /// Duration of the fade-in animation
  final Duration fadeInDuration;

  /// The curve to use for the fade-in animation
  final Curve fadeInCurve;

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

  /// Whether to enable markdown rendering
  final bool markdownEnabled;

  /// Whether to enable LaTeX rendering
  final bool latexEnabled;

  /// Custom style for LaTeX expressions
  final TextStyle? latexStyle;

  /// Scale factor for LaTeX equations
  final double latexScale;

  /// Whether to enable fade-in animations for LaTeX content
  final bool? latexFadeInEnabled;

  /// Controller for programmatic animation control
  final StreamingTextController? controller;

  /// Callback when animation completes
  final VoidCallback? onComplete;

  /// Whether animations are enabled. When false, text appears instantly.
  final bool animationsEnabled;

  /// Whether to show a shimmer skeleton placeholder instead of the text widget.
  ///
  /// Set to `true` while waiting for the first LLM token to arrive
  /// (TTFT — Time To First Token). The shimmer automatically disappears
  /// when you set this back to `false`.
  ///
  /// Defaults to `false` — existing code is completely unaffected.
  ///
  /// Example:
  /// ```dart
  /// StreamingTextMarkdown(
  ///   text: _streamedText,
  ///   isLoading: _waitingForFirstToken,
  /// )
  /// ```
  final bool isLoading;

  /// Number of shimmer skeleton lines shown while [isLoading] is true.
  /// Defaults to 3.
  final int shimmerLineCount;

  /// Custom builder for images in markdown content.
  final Widget Function(BuildContext context, String imageUrl)? imageBuilder;

  /// Callback when a link is tapped in markdown content.
  final void Function(String url, String title)? onLinkTap;

  /// Custom builder for code blocks in markdown content.
  final Widget Function(BuildContext context, String name, String code, bool closed)? codeBuilder;

  /// Custom builder for LaTeX expressions in markdown content.
  final Widget Function(BuildContext context, String tex, TextStyle textStyle, bool inline)? latexBuilder;

  /// Custom builder for source tags in markdown content.
  final Widget Function(BuildContext context, String content, TextStyle textStyle)? sourceTagBuilder;

  /// Custom builder for highlighted text in markdown content.
  final Widget Function(BuildContext context, String text, TextStyle style)? highlightBuilder;

  /// Custom builder for links in markdown content.
  final Widget Function(BuildContext context, InlineSpan text, String url, TextStyle style)? linkBuilder;

  const StreamingTextMarkdown({
    super.key,
    required this.text,
    this.initialText = '',
    this.styleSheet,
    this.theme,
    this.padding,
    this.autoScroll = true,
    this.fadeInEnabled = false,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.fadeInCurve = Curves.easeOut,
    this.wordByWord = false,
    this.chunkSize = 1,
    this.typingSpeed = const Duration(milliseconds: 50),
    this.textDirection,
    this.textAlign,
    this.markdownEnabled = false,
    this.latexEnabled = false,
    this.latexStyle,
    this.latexScale = 1.0,
    this.latexFadeInEnabled,
    this.controller,
    this.onComplete,
    this.animationsEnabled = true,
    this.isLoading = false,
    this.shimmerLineCount = 3,
    this.imageBuilder,
    this.onLinkTap,
    this.codeBuilder,
    this.latexBuilder,
    this.sourceTagBuilder,
    this.highlightBuilder,
    this.linkBuilder,
  });

  /// Creates a StreamingTextMarkdown with ChatGPT-style animation
  /// Perfect for fast, character-by-character streaming like ChatGPT
  const StreamingTextMarkdown.chatGPT({
    super.key,
    required this.text,
    this.initialText = '',
    this.styleSheet,
    this.theme,
    this.padding,
    this.autoScroll = true,
    this.textDirection,
    this.textAlign,
    this.markdownEnabled = true,
    this.latexEnabled = false,
    this.latexStyle,
    this.latexScale = 1.0,
    this.latexFadeInEnabled,
    this.controller,
    this.onComplete,
    this.animationsEnabled = true,
    this.isLoading = false,
    this.shimmerLineCount = 3,
    this.imageBuilder,
    this.onLinkTap,
    this.codeBuilder,
    this.latexBuilder,
    this.sourceTagBuilder,
    this.highlightBuilder,
    this.linkBuilder,
  })  : fadeInEnabled = true,
        fadeInDuration = const Duration(milliseconds: 150),
        fadeInCurve = Curves.easeOut,
        wordByWord = false,
        chunkSize = 1,
        typingSpeed = const Duration(milliseconds: 15);

  /// Creates a StreamingTextMarkdown with Claude-style animation
  /// Perfect for smooth, word-by-word streaming like Claude
  const StreamingTextMarkdown.claude({
    super.key,
    required this.text,
    this.initialText = '',
    this.styleSheet,
    this.theme,
    this.padding,
    this.autoScroll = true,
    this.textDirection,
    this.textAlign,
    this.markdownEnabled = true,
    this.latexEnabled = false,
    this.latexStyle,
    this.latexScale = 1.0,
    this.latexFadeInEnabled,
    this.controller,
    this.onComplete,
    this.animationsEnabled = true,
    this.isLoading = false,
    this.shimmerLineCount = 3,
    this.imageBuilder,
    this.onLinkTap,
    this.codeBuilder,
    this.latexBuilder,
    this.sourceTagBuilder,
    this.highlightBuilder,
    this.linkBuilder,
  })  : fadeInEnabled = true,
        fadeInDuration = const Duration(milliseconds: 200),
        fadeInCurve = Curves.easeInOut,
        wordByWord = true,
        chunkSize = 1,
        typingSpeed = const Duration(milliseconds: 80);

  /// Creates a StreamingTextMarkdown with typewriter animation
  /// Classic typewriter effect without fade-in
  const StreamingTextMarkdown.typewriter({
    super.key,
    required this.text,
    this.initialText = '',
    this.styleSheet,
    this.theme,
    this.padding,
    this.autoScroll = true,
    this.textDirection,
    this.textAlign,
    this.markdownEnabled = false,
    this.latexEnabled = false,
    this.latexStyle,
    this.latexScale = 1.0,
    this.latexFadeInEnabled,
    this.controller,
    this.onComplete,
    this.animationsEnabled = true,
    this.isLoading = false,
    this.shimmerLineCount = 3,
    this.imageBuilder,
    this.onLinkTap,
    this.codeBuilder,
    this.latexBuilder,
    this.sourceTagBuilder,
    this.highlightBuilder,
    this.linkBuilder,
  })  : fadeInEnabled = false,
        fadeInDuration = Duration.zero,
        fadeInCurve = Curves.linear,
        wordByWord = false,
        chunkSize = 1,
        typingSpeed = const Duration(milliseconds: 50);

  /// Creates a StreamingTextMarkdown with instant display
  /// For when speed is priority over animation
  const StreamingTextMarkdown.instant({
    super.key,
    required this.text,
    this.initialText = '',
    this.styleSheet,
    this.theme,
    this.padding,
    this.autoScroll = true,
    this.textDirection,
    this.textAlign,
    this.markdownEnabled = false,
    this.latexEnabled = false,
    this.latexStyle,
    this.latexScale = 1.0,
    this.latexFadeInEnabled,
    this.controller,
    this.onComplete,
    this.animationsEnabled = false,
    this.isLoading = false,
    this.shimmerLineCount = 3,
    this.imageBuilder,
    this.onLinkTap,
    this.codeBuilder,
    this.latexBuilder,
    this.sourceTagBuilder,
    this.highlightBuilder,
    this.linkBuilder,
  })  : fadeInEnabled = false,
        fadeInDuration = Duration.zero,
        fadeInCurve = Curves.linear,
        wordByWord = false,
        chunkSize = 1000,
        typingSpeed = Duration.zero;

  /// Creates a StreamingTextMarkdown from a preset configuration
  StreamingTextMarkdown.fromPreset({
    super.key,
    required this.text,
    required StreamingTextConfig preset,
    this.initialText = '',
    this.styleSheet,
    this.theme,
    this.padding,
    this.autoScroll = true,
    this.textDirection,
    this.textAlign,
    this.markdownEnabled = false,
    this.latexEnabled = false,
    this.latexStyle,
    this.latexScale = 1.0,
    this.latexFadeInEnabled,
    this.controller,
    this.onComplete,
    this.animationsEnabled = true,
    this.isLoading = false,
    this.shimmerLineCount = 3,
    this.imageBuilder,
    this.onLinkTap,
    this.codeBuilder,
    this.latexBuilder,
    this.sourceTagBuilder,
    this.highlightBuilder,
    this.linkBuilder,
  })  : fadeInEnabled = preset.fadeInEnabled,
        fadeInDuration = preset.fadeInDuration,
        fadeInCurve = preset.fadeInCurve,
        wordByWord = preset.wordByWord,
        chunkSize = preset.chunkSize,
        typingSpeed = preset.typingSpeed;

  @override
  State<StreamingTextMarkdown> createState() => _StreamingTextMarkdownState();
}

class _StreamingTextMarkdownState extends State<StreamingTextMarkdown> {
  final ScrollController _scrollController = ScrollController();
  late StreamingTextTheme _effectiveTheme;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update effective theme when dependencies change
    _effectiveTheme = widget.theme ?? context.streamingTextTheme;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Resolve TextStyle with proper fallback chain
    // Priority: widget.styleSheet > theme.markdownStyleSheet > theme.markdownStyle (deprecated) > default
    final effectiveStyleSheet = widget.styleSheet ??
        _effectiveTheme.markdownStyleSheet ??
        Theme.of(context).textTheme.bodyLarge;

    final effectivePadding = widget.padding ??
        _effectiveTheme.defaultPadding ??
        const EdgeInsets.all(16.0);

    // Show shimmer skeleton while waiting for first LLM token
    if (widget.isLoading) {
      return Padding(
        padding: effectivePadding,
        child: StreamingShimmer(lineCount: widget.shimmerLineCount),
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      child: Padding(
        padding: effectivePadding,
        child: StreamingText(
          key: ValueKey(
              'streaming_text_${widget.wordByWord}_${widget.chunkSize}_${widget.typingSpeed.inMilliseconds}_${widget.latexEnabled}'),
          text: widget.text,
          style: _effectiveTheme.textStyle,
          markdownEnabled: widget.markdownEnabled,
          latexEnabled: widget.latexEnabled,
          latexStyle: widget.latexStyle ?? _effectiveTheme.inlineLatexStyle,
          latexScale: widget.latexScale,
          latexFadeInEnabled:
              widget.latexFadeInEnabled ?? _effectiveTheme.latexFadeInEnabled,
          markdownStyleSheet: effectiveStyleSheet,
          fadeInEnabled: widget.fadeInEnabled,
          fadeInDuration: widget.fadeInDuration,
          fadeInCurve: widget.fadeInCurve,
          wordByWord: widget.wordByWord,
          chunkSize: widget.chunkSize,
          typingSpeed: widget.typingSpeed,
          textDirection: widget.textDirection,
          textAlign: widget.textAlign,
          controller: widget.controller,
          animationsEnabled: widget.animationsEnabled,
          imageBuilder: widget.imageBuilder,
          onLinkTap: widget.onLinkTap,
          codeBuilder: widget.codeBuilder,
          latexBuilder: widget.latexBuilder,
          sourceTagBuilder: widget.sourceTagBuilder,
          highlightBuilder: widget.highlightBuilder,
          linkBuilder: widget.linkBuilder,
          onComplete: () {
            // Handle auto-scrolling
            if (mounted && widget.autoScroll && _scrollController.hasClients) {
              // Use a post-frame callback to ensure the scroll controller is properly initialized
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _scrollController.hasClients) {
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                }
              });
            }
            // Call user's completion callback
            widget.onComplete?.call();
          },
        ),
      ),
    );
  }
}
