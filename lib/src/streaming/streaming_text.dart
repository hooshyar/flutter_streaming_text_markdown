import 'package:flutter/material.dart';
import 'dart:async';
import 'package:characters/characters.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// A widget that displays streaming text with real-time updates and markdown support.
class StreamingText extends StatefulWidget {
  /// Creates a streaming text widget.
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
    this.textScaleFactor,
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
  final double? textScaleFactor;

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
  late Animation<double> _cursorAnimation;
  bool _isComplete = false;
  bool _isError = false;
  String? _errorMessage;
  bool _isDisposed = false;

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

    _cursorAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cursorController,
      curve: Curves.easeInOut,
    ));

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

    final isRTL = widget.textDirection == TextDirection.rtl;

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
        if (isRTL) {
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

      _typeTimer = Timer.periodic(widget.typingSpeed, (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        final remainingChars = characters.length - index;
        final charsToReveal = widget.chunkSize <= remainingChars
            ? widget.chunkSize
            : remainingChars;

        if (charsToReveal <= 0) {
          timer.cancel();
          if (mounted) {
            setState(() => _isComplete = true);
            widget.onComplete?.call();
          }
          return;
        }

        if (mounted) {
          setState(() {
            _displayedText +=
                characters.sublist(index, index + charsToReveal).join();
          });
          _createCharacterAnimation(index, charsToReveal);
        }

        if (RegExp(r'[.,!?؟،]')
            .hasMatch(characters[index + charsToReveal - 1])) {
          timer.cancel();
          Future.delayed(widget.typingSpeed * 4, () {
            if (mounted) {
              _startTyping();
            }
          });
        }

        index += charsToReveal;
      });
    }
  }

  void _cleanup() {
    _typeTimer?.cancel();
    _streamSubscription?.cancel();

    // Stop and dispose all character animations
    for (final controller in _characterAnimations.values.toList()) {
      try {
        if (controller.isAnimating) {
          controller.stop();
        }
        controller.dispose();
      } catch (e) {
        // Controller might already be disposed
      }
    }
    _characterAnimations.clear();
  }

  void _disposeAnimations() {
    // Stop and dispose cursor animation
    try {
      if (_cursorController.isAnimating) {
        _cursorController.stop();
      }
      _cursorController.dispose();
    } catch (e) {
      // Controller might already be disposed
    }
  }

  @override
  void dispose() {
    _cleanup();
    _disposeAnimations();
    super.dispose();
  }

  @override
  void didUpdateWidget(StreamingText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.text != oldWidget.text ||
        widget.showCursor != oldWidget.showCursor) {
      _cleanup();
      _disposeAnimations();
      if (mounted) {
        setState(() {
          _displayedText = '';
          _isComplete = false;
        });
        _initCursorAnimation();
        _initializeText();
      }
    }
  }

  Widget _buildAnimatedCharacter(String char, int index, TextStyle baseStyle) {
    final controller = _characterAnimations[index];
    final isRTL = widget.textDirection == TextDirection.rtl;

    Widget buildText(String text, {TextStyle? style}) {
      final effectiveStyle =
          _applyMarkdownStyle(text, index, style ?? baseStyle);
      return Text(
        text,
        style: effectiveStyle,
        textDirection: widget.textDirection,
        textAlign: widget.textAlign,
      );
    }

    if (controller == null || !widget.fadeInEnabled) {
      return buildText(char);
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            0,
            10 * (1 - controller.value),
          ),
          child: Opacity(
            opacity: controller.value,
            child: child,
          ),
        );
      },
      child: buildText(char),
    );
  }

  TextStyle _applyMarkdownStyle(String text, int index, TextStyle baseStyle) {
    if (!widget.markdownEnabled) return baseStyle;

    bool isBold = _isMarkdownBold(index);
    bool isItalic = _isMarkdownItalic(index);

    return baseStyle.copyWith(
      fontWeight: isBold ? FontWeight.bold : null,
      fontStyle: isItalic ? FontStyle.italic : null,
    );
  }

  Widget _buildAnimatedWord(String word, int index, TextStyle baseStyle) {
    final controller = _characterAnimations[index];

    Widget buildText(String text, {TextStyle? style}) {
      final effectiveStyle =
          _applyMarkdownStyle(text, index, style ?? baseStyle);
      return Text(
        text,
        style: effectiveStyle,
        textDirection: widget.textDirection,
        textAlign: widget.textAlign,
      );
    }

    if (controller == null || !widget.fadeInEnabled) {
      return buildText(word);
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            0,
            10 * (1 - controller.value),
          ),
          child: Opacity(
            opacity: controller.value,
            child: child,
          ),
        );
      },
      child: buildText(word),
    );
  }

  bool _isMarkdownBold(int index) {
    // Check if character is between ** or __ markers
    final text = _displayedText;
    if (index >= text.length) return false;

    // Look for ** or __ before the current position
    int start = index;
    while (start > 1) {
      if ((text[start - 2] == '*' && text[start - 1] == '*') ||
          (text[start - 2] == '_' && text[start - 1] == '_')) {
        // Look for matching ** or __ after the current position
        int end = index;
        while (end < text.length - 1) {
          if ((text[end] == '*' && text[end + 1] == '*') ||
              (text[end] == '_' && text[end + 1] == '_')) {
            return true;
          }
          end++;
        }
      }
      start--;
    }
    return false;
  }

  bool _isMarkdownItalic(int index) {
    // Check if character is between * or _ markers
    final text = _displayedText;
    if (index >= text.length) return false;

    // Look for * or _ before the current position
    int start = index;
    while (start > 0) {
      if (text[start - 1] == '*' || text[start - 1] == '_') {
        // Look for matching * or _ after the current position
        int end = index;
        while (end < text.length) {
          if (text[end] == '*' || text[end] == '_') {
            // Make sure it's not part of a bold marker
            if (end < text.length - 1 &&
                (text[end + 1] == '*' || text[end + 1] == '_')) {
              end++;
              continue;
            }
            return true;
          }
          end++;
        }
      }
      start--;
    }
    return false;
  }

  Widget _buildContent(BuildContext context) {
    if (_isError) {
      return Text(
        'Error: ${_errorMessage ?? 'Unknown error'}',
        style: widget.style?.copyWith(color: Colors.red) ??
            TextStyle(color: Colors.red),
      );
    }

    final defaultStyle = DefaultTextStyle.of(context).style;
    final effectiveStyle = widget.style ?? defaultStyle;

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

    // For fade-in animation with markdown
    if (widget.fadeInEnabled) {
      final lines = _displayedText.split('\n');
      final isRTL = widget.textDirection == TextDirection.rtl;

      return Directionality(
        textDirection: widget.textDirection ?? TextDirection.ltr,
        child: Column(
          crossAxisAlignment: widget.textAlign == TextAlign.center
              ? CrossAxisAlignment.center
              : isRTL
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
          children: lines.map((line) {
            if (line.isEmpty) return const SizedBox(height: 20);

            // Check for heading level
            int headingLevel = 0;
            String processedLine = line;
            if (widget.markdownEnabled) {
              while (processedLine.startsWith('#')) {
                headingLevel++;
                processedLine = processedLine.substring(1);
              }
              processedLine = processedLine.trim();
            }

            // Apply heading style
            TextStyle lineStyle = effectiveStyle;
            if (headingLevel > 0) {
              final scaleFactor = 2.0 - ((headingLevel - 1) * 0.3);
              lineStyle = lineStyle.copyWith(
                fontSize: effectiveStyle.fontSize! * scaleFactor,
                fontWeight: FontWeight.bold,
              );
            }

            // For RTL, handle text as words
            if (isRTL) {
              final words =
                  processedLine.split(' ').where((w) => w.isNotEmpty).toList();
              return Container(
                width: double.infinity,
                alignment: widget.textAlign == TextAlign.center
                    ? Alignment.center
                    : Alignment.centerRight,
                child: Wrap(
                  direction: Axis.horizontal,
                  alignment: widget.textAlign == TextAlign.center
                      ? WrapAlignment.center
                      : WrapAlignment.end,
                  children: words.asMap().entries.map((entry) {
                    final wordIndex = entry.key;
                    final word = entry.value;
                    final baseIndex =
                        lines.take(lines.indexOf(line)).join('\n').length +
                            words.take(wordIndex).join(' ').length +
                            wordIndex;

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildAnimatedWord(word, baseIndex, lineStyle),
                        if (wordIndex < words.length - 1)
                          Text(' ', style: lineStyle),
                      ],
                    );
                  }).toList(),
                ),
              );
            }

            // For LTR text
            final words = processedLine.split(' ');
            return Wrap(
              direction: Axis.horizontal,
              alignment: widget.textAlign == TextAlign.center
                  ? WrapAlignment.center
                  : WrapAlignment.start,
              children: words.asMap().entries.map((wordEntry) {
                final wordIndex = wordEntry.key;
                final word = wordEntry.value;
                final baseIndex =
                    lines.take(lines.indexOf(line)).join('\n').length +
                        words.take(wordIndex).join(' ').length +
                        (wordIndex > 0 ? 1 : 0);

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...word.characters
                        .toList()
                        .asMap()
                        .entries
                        .map((charEntry) {
                      final charIndex = baseIndex + charEntry.key;
                      return _buildAnimatedCharacter(
                          charEntry.value, charIndex, lineStyle);
                    }),
                    if (wordEntry.key < words.length - 1)
                      Text(' ', style: lineStyle),
                  ],
                );
              }).toList(),
            );
          }).toList(),
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
      textScaleFactor: widget.textScaleFactor ?? 1.0,
      maxLines: widget.maxLines,
      strutStyle: widget.strutStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Skip to end on tap
        _cleanup();
        setState(() {
          _displayedText = widget.text;
          _isComplete = true;
        });
        widget.onComplete?.call();
      },
      child: _buildContent(context),
    );
  }
}
