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

  final String text;
  final Duration typingSpeed;
  final bool wordByWord;
  final int chunkSize;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  @Deprecated('Use textScaler instead')
  final double? textScaleFactor;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final bool selectable;
  final bool showCursor;
  final Color? cursorColor;
  final VoidCallback? onComplete;
  final Stream<String>? stream;
  final bool markdownEnabled;
  final bool fadeInEnabled;
  final Duration fadeInDuration;
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

    for (int i = 0; i < length; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: widget.fadeInDuration,
      );
      _characterAnimations[baseIndex + i] = controller;
      controller.forward();
    }
  }

  void _startTyping() {
    if (_isComplete) return;

    if (widget.wordByWord) {
      _startWordByWordTyping();
    } else {
      _startCharacterByCharacterTyping();
    }
  }

  void _startWordByWordTyping() {
    final words = widget.text.split(RegExp(r'\s+'));
    final isRTL = widget.textDirection == TextDirection.rtl ||
        _containsArabic(widget.text);
    int wordIndex = 0;

    _typeTimer?.cancel();
    _typeTimer = Timer.periodic(widget.typingSpeed, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (wordIndex >= words.length) {
        timer.cancel();
        setState(() => _isComplete = true);
        widget.onComplete?.call();
        return;
      }

      setState(() {
        if (_displayedText.isNotEmpty) _displayedText = '$_displayedText ';
        _displayedText = '$_displayedText${words[wordIndex]}';

        if (widget.fadeInEnabled) {
          _createCharacterAnimation(
              _displayedText.length - words[wordIndex].length,
              words[wordIndex].length);
        }
      });

      wordIndex++;
    });
  }

  void _startCharacterByCharacterTyping() {
    final characters = Characters(widget.text).toList();
    int index = 0;

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
            characters.getRange(index, index + currentChunkSize).join();
        _displayedText = '$_displayedText$chunk';

        if (widget.fadeInEnabled) {
          _createCharacterAnimation(
              _displayedText.length - currentChunkSize, currentChunkSize);
        }
      });

      index += currentChunkSize;
    });
  }

  void _cleanupAnimations() {
    for (final controller in _characterAnimations.values) {
      try {
        controller.dispose();
      } catch (e) {
        // Skip if controller is already disposed
      }
    }
    _characterAnimations.clear();
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

  Widget _buildContent(BuildContext context) {
    if (_isError) {
      return Text(
        'Error: ${_errorMessage ?? 'Unknown error'}',
        style: widget.style?.copyWith(color: Colors.red) ??
            const TextStyle(color: Colors.red),
      );
    }

    final effectiveStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final isRTLText = _containsArabic(_displayedText);
    final effectiveTextDirection = widget.textDirection ??
        (isRTLText ? TextDirection.rtl : TextDirection.ltr);
    final effectiveAlignment =
        widget.textAlign ?? (isRTLText ? TextAlign.right : TextAlign.left);

    // If markdown is enabled, use MarkdownBody without fade-in
    if (widget.markdownEnabled) {
      return Directionality(
        textDirection: effectiveTextDirection,
        child: MarkdownBody(
          data: _displayedText,
          selectable: widget.selectable,
          styleSheet: MarkdownStyleSheet(
            p: effectiveStyle,
            strong: effectiveStyle.copyWith(fontWeight: FontWeight.bold),
            em: effectiveStyle.copyWith(fontStyle: FontStyle.italic),
            h1: effectiveStyle.copyWith(
              fontSize: effectiveStyle.fontSize! * 2.0,
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
            h4: effectiveStyle.copyWith(
              fontSize: effectiveStyle.fontSize! * 1.0,
              fontWeight: FontWeight.bold,
            ),
            h5: effectiveStyle.copyWith(
              fontSize: effectiveStyle.fontSize! * 0.83,
              fontWeight: FontWeight.bold,
            ),
            h6: effectiveStyle.copyWith(
              fontSize: effectiveStyle.fontSize! * 0.67,
              fontWeight: FontWeight.bold,
            ),
            listBullet: effectiveStyle,
            blockquote: effectiveStyle.copyWith(
              color: effectiveStyle.color?.withOpacity(0.6),
              fontStyle: FontStyle.italic,
            ),
            code: effectiveStyle.copyWith(
              backgroundColor: Colors.grey.withOpacity(0.2),
              fontFamily: 'monospace',
            ),
            codeblockPadding: const EdgeInsets.all(8),
            blockquotePadding: const EdgeInsets.symmetric(horizontal: 16),
            blockquoteDecoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color:
                      (effectiveStyle.color ?? Colors.black).withOpacity(0.4),
                  width: 4,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // For simple text with fade-in animation
    if (widget.fadeInEnabled) {
      final lines = _displayedText.split('\n');
      final isRTL = effectiveTextDirection == TextDirection.rtl;

      return Column(
        crossAxisAlignment: widget.textAlign == TextAlign.center
            ? CrossAxisAlignment.center
            : isRTL
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
        children: lines.map((line) {
          if (line.isEmpty) return const SizedBox(height: 20);

          var words = line.split(' ').where((w) => w.isNotEmpty).toList();
          // if (isRTL) words = words.reversed.toList();

          return Container(
            width: double.infinity,
            alignment: effectiveAlignment == TextAlign.right
                ? Alignment.centerRight
                : effectiveAlignment == TextAlign.center
                    ? Alignment.center
                    : Alignment.centerLeft,
            child: Wrap(
              direction: Axis.horizontal,
              alignment: isRTL ? WrapAlignment.end : WrapAlignment.start,
              textDirection: effectiveTextDirection,
              children: words.asMap().entries.map((entry) {
                final wordIndex = entry.key;
                final word = entry.value;
                final baseIndex =
                    lines.take(lines.indexOf(line)).join('\n').length +
                        (isRTL
                            ? words.skip(wordIndex + 1).join(' ').length
                            : words.take(wordIndex).join(' ').length) +
                        wordIndex;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  textDirection: effectiveTextDirection,
                  children: [
                    _buildAnimatedText(word, baseIndex, effectiveStyle),
                    if (wordIndex < words.length - 1)
                      Text(' ', style: effectiveStyle),
                  ],
                );
              }).toList(),
            ),
          );
        }).toList(),
      );
    }

    // Simple text rendering without animation
    return Text(
      _displayedText,
      style: effectiveStyle,
      textAlign: effectiveAlignment,
      textDirection: effectiveTextDirection,
      softWrap: widget.softWrap ?? true,
      overflow: widget.overflow ?? TextOverflow.clip,
      textScaler: widget.textScaler ?? MediaQuery.textScalerOf(context),
      maxLines: widget.maxLines,
      strutStyle: widget.strutStyle,
    );
  }

  Widget _buildAnimatedText(String text, int index, TextStyle baseStyle) {
    final controller = _characterAnimations[index];
    final isArabicText = _containsArabic(text);
    final effectiveTextDirection = widget.textDirection ??
        (isArabicText ? TextDirection.rtl : TextDirection.ltr);

    if (controller == null || !widget.fadeInEnabled) {
      return Directionality(
        textDirection: effectiveTextDirection,
        child: Text(text, style: baseStyle),
      );
    }

    return Directionality(
      textDirection: effectiveTextDirection,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, 10 * (1 - controller.value)),
            child: Opacity(
              opacity: controller.value,
              child: child,
            ),
          );
        },
        child: Text(text, style: baseStyle),
      ),
    );
  }

  bool _containsArabic(String text) {
    // Unicode ranges for RTL scripts:
    // - Arabic: \u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF
    // - Hebrew: \u0590-\u05FF
    // - Syriac: \u0700-\u074F
    // - Thaana: \u0780-\u07BF
    // - N'Ko: \u07C0-\u07FF
    return RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF'
      r'\u0590-\u05FF'
      r'\u0700-\u074F'
      r'\u0780-\u07BF'
      r'\u07C0-\u07FF]',
    ).hasMatch(text);
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _streamSubscription?.cancel();
    _cursorController.dispose();
    _cleanupAnimations();
    super.dispose();
  }
}
