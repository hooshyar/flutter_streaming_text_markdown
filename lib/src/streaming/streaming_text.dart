import 'package:flutter/material.dart';
import 'dart:async';
import 'package:characters/characters.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// A widget that displays streaming text with real-time updates and markdown support.
///
/// This widget provides a rich text display with features like:
/// * Character-by-character or word-by-word typing animation
/// * Markdown rendering with support for bold, italic, and headers
/// * Fade-in animations for smooth text appearance
/// * RTL (Right-to-Left) language support
/// * Real-time text streaming capabilities
/// * Customizable typing speed and animation durations
///
/// Example usage:
/// ```dart
/// StreamingText(
///   text: '**Hello** _world_!',
///   typingSpeed: Duration(milliseconds: 50),
///   fadeInEnabled: true,
///   wordByWord: true,
///   markdownEnabled: true,
/// )
/// ```
class StreamingText extends StatefulWidget {
  /// Creates a streaming text widget.
  ///
  /// The [text] parameter must not be null and contains the text to be displayed.
  /// Use [typingSpeed] to control the animation speed and [wordByWord] to choose
  /// between character-by-character or word-by-word animation.
  const StreamingText({
    super.key,
    required this.text,
    this.typingSpeed = const Duration(milliseconds: 50),
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    @Deprecated('Use textScaler instead') this.textScaleFactor,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectable = false,
    this.showCursor = true,
    this.cursorColor,
    this.onComplete,
    this.stream,
    this.markdownEnabled = true,
    this.fadeInEnabled = false,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.fadeInCurve = Curves.easeOut,
    this.wordByWord = false,
    this.chunkSize = 1,
  });

  /// The text to display with the typing animation.
  final String text;

  /// The speed at which each character or word appears.
  final Duration typingSpeed;

  /// Whether to stream text word by word instead of character by character.
  final bool wordByWord;

  /// The number of characters to reveal at once when not in word-by-word mode.
  /// Ignored if wordByWord is true.
  final int chunkSize;

  /// The text style to apply to the text.
  final TextStyle? style;

  /// The strut style to apply to the text.
  final StrutStyle? strutStyle;

  /// How the text should be aligned horizontally.
  final TextAlign? textAlign;

  /// The directionality of the text.
  final TextDirection? textDirection;

  /// Used to select a font when the same Unicode character can
  /// be rendered differently, depending on the locale.
  final Locale? locale;

  /// Whether the text should break at soft line breaks.
  final bool? softWrap;

  /// How visual overflow should be handled.
  final TextOverflow? overflow;

  /// The number of font pixels for each logical pixel.
  @Deprecated('Use textScaler instead')
  final double? textScaleFactor;

  /// The text scaling factor to use.
  final TextScaler? textScaler;

  /// An optional maximum number of lines for the text to span.
  final int? maxLines;

  /// An alternative semantics label for the text.
  final String? semanticsLabel;

  /// Defines how to measure the width of the rendered text.
  final TextWidthBasis? textWidthBasis;

  /// Defines how the paragraph will apply TextStyle.height to the rendered text.
  final TextHeightBehavior? textHeightBehavior;

  /// Whether the text should be selectable.
  final bool selectable;

  /// Whether to show a blinking cursor.
  final bool showCursor;

  /// The color of the cursor.
  final Color? cursorColor;

  /// Callback to be called when typing is complete.
  final VoidCallback? onComplete;

  /// Optional stream of text data for real-time updates.
  final Stream<String>? stream;

  /// Whether to enable markdown rendering.
  final bool markdownEnabled;

  /// Whether to enable fade-in animation for each character.
  final bool fadeInEnabled;

  /// Duration of the fade-in animation for each character.
  final Duration fadeInDuration;

  /// Curve of the fade-in animation.
  final Curve fadeInCurve;

  @override
  State<StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<StreamingText>
    with TickerProviderStateMixin {
  String _displayedText = '';
  Timer? _typeTimer;
  StreamSubscription<String>? _streamSubscription;
  late AnimationController _cursorController;
  bool _isComplete = false;
  bool _isError = false;
  String? _errorMessage;

  // Keep track of character animations
  final Map<int, AnimationController> _characterAnimations = {};

  @override
  void initState() {
    super.initState();
    _initCursorAnimation();
    _initializeText();
  }

  void _initCursorAnimation() {
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    if (widget.showCursor) {
      _cursorController.repeat(reverse: true);
    }
  }

  void _initializeText() {
    if (widget.stream != null) {
      _handleStream();
    } else {
      _startTyping();
    }
  }

  void _handleStream() {
    _streamSubscription?.cancel();
    final broadcastStream = widget.stream!.asBroadcastStream();
    _streamSubscription = broadcastStream.listen(
      (data) {
        setState(() {
          _displayedText += data;
          _isError = false;
          _errorMessage = null;
        });
      },
      onError: (error) {
        setState(() {
          _isError = true;
          _errorMessage = error.toString();
        });
      },
      onDone: () {
        setState(() => _isComplete = true);
        widget.onComplete?.call();
      },
    );
  }

  void _createCharacterAnimation(int baseIndex, int length) {
    if (!mounted || !widget.fadeInEnabled) return;

    final controller = AnimationController(
      vsync: this,
      duration: widget.fadeInDuration,
    );

    for (int i = 0; i < length; i++) {
      _characterAnimations[baseIndex + i] = controller;
    }

    controller.forward().whenComplete(() {
      if (!mounted) {
        controller.dispose();
        return;
      }
      for (int i = 0; i < length; i++) {
        _characterAnimations.remove(baseIndex + i);
      }
      controller.dispose();
    });
  }

  void _startTyping() {
    if (_isComplete) return;

    if (widget.wordByWord) {
      final lines = widget.text.split('\n');
      int currentLine = 0;
      bool isFirstWordInLine = true;

      void processNextLine() {
        if (!mounted) return;
        if (currentLine >= lines.length) {
          setState(() => _isComplete = true);
          widget.onComplete?.call();
          return;
        }

        final line = lines[currentLine];

        // Handle empty lines
        if (line.trim().isEmpty) {
          if (mounted) {
            setState(() {
              _displayedText += '\n';
            });
          }
          currentLine++;
          processNextLine();
          return;
        }

        final lineWords = line.split(' ').where((w) => w.isNotEmpty).toList();

        // Reverse words for RTL
        if (widget.textDirection == TextDirection.rtl) {
          lineWords.reversed.toList();
        }

        int wordIndex = 0;

        _typeTimer?.cancel();
        _typeTimer = Timer.periodic(widget.typingSpeed, (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }

          if (wordIndex >= lineWords.length) {
            timer.cancel();
            if (mounted) {
              setState(() {
                if (currentLine < lines.length - 1) {
                  _displayedText += '\n';
                }
              });
            }
            currentLine++;
            isFirstWordInLine = true;
            processNextLine();
            return;
          }

          if (mounted) {
            setState(() {
              if (!isFirstWordInLine) {
                _displayedText += ' ';
              }
              _displayedText += lineWords[wordIndex];
              isFirstWordInLine = false;
            });

            final baseIndex =
                _displayedText.length - lineWords[wordIndex].length;
            _createCharacterAnimation(baseIndex, lineWords[wordIndex].length);
          }

          wordIndex++;
        });
      }

      processNextLine();
    } else {
      final characters = Characters(widget.text).toList();
      int index = _displayedText.characters.length;

      _typeTimer?.cancel();
      _typeTimer = Timer.periodic(widget.typingSpeed, (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (index >= characters.length) {
          timer.cancel();
          setState(() => _isComplete = true);
          widget.onComplete?.call();
          return;
        }

        final chunkSize = widget.chunkSize;
        final remainingChars = characters.length - index;
        final currentChunkSize =
            chunkSize > remainingChars ? remainingChars : chunkSize;

        setState(() {
          final chunk =
              characters.sublist(index, index + currentChunkSize).join();
          _displayedText += chunk;
          _createCharacterAnimation(index, currentChunkSize);
        });

        index += currentChunkSize;
      });
    }
  }

  Widget _buildContent(BuildContext context) {
    if (_isError) {
      return Text(
        'Error: ${_errorMessage ?? 'Unknown error'}',
        style: widget.style?.copyWith(color: Colors.red) ??
            const TextStyle(color: Colors.red),
      );
    }

    final effectiveStyle = widget.style ?? DefaultTextStyle.of(context).style;

    // If markdown is enabled and no fade-in animation, use MarkdownBody directly
    if (widget.markdownEnabled && !widget.fadeInEnabled) {
      return Directionality(
        textDirection: widget.textDirection ?? TextDirection.ltr,
        child: MarkdownBody(
          data: _displayedText,
          selectable: widget.selectable,
          styleSheet: MarkdownStyleSheet(
            h1: effectiveStyle.copyWith(
              fontSize: effectiveStyle.fontSize! * 2,
              fontWeight: FontWeight.bold,
            ),
            h2: effectiveStyle.copyWith(
              fontSize: effectiveStyle.fontSize! * 1.5,
              fontWeight: FontWeight.bold,
            ),
            h3: effectiveStyle.copyWith(
              fontSize: effectiveStyle.fontSize! * 1.17,
              fontWeight: FontWeight.bold,
            ),
            p: effectiveStyle,
            strong: effectiveStyle.copyWith(fontWeight: FontWeight.bold),
            em: effectiveStyle.copyWith(fontStyle: FontStyle.italic),
            listBullet: effectiveStyle,
          ),
          softLineBreak: true,
        ),
      );
    }

    // Simple text rendering without markdown or fade-in
    return Text(
      _displayedText,
      style: effectiveStyle,
      textAlign: widget.textAlign ?? TextAlign.start,
      textDirection: widget.textDirection,
      softWrap: widget.softWrap ?? true,
      overflow: widget.overflow ?? TextOverflow.clip,
      textScaler: widget.textScaler ?? MediaQuery.textScalerOf(context),
      maxLines: widget.maxLines,
      strutStyle: widget.strutStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Skip to end on tap
        _typeTimer?.cancel();
        setState(() {
          _displayedText = widget.text;
          _isComplete = true;
        });
        widget.onComplete?.call();
      },
      child: _buildContent(context),
    );
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _streamSubscription?.cancel();
    _cursorController.dispose();
    for (final controller in _characterAnimations.values) {
      controller.dispose();
    }
    _characterAnimations.clear();
    super.dispose();
  }
}
