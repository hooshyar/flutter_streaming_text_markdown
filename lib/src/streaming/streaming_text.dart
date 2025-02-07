import 'package:flutter/material.dart';
import 'dart:async';
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
    this.markdownStyleSheet,
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
  final MarkdownStyleSheet? markdownStyleSheet;

  @override
  State<StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<StreamingText>
    with TickerProviderStateMixin {
  // If the text is Arabic, disable fade-in animation.
  bool get _fadeInAllowed {
    // Re-check the actual displayed text for Arabic:
    return widget.fadeInEnabled &&
        widget.stream == null &&
        !_containsArabic(_displayedText);
  }

  final StringBuffer _displayedTextBuffer = StringBuffer();

  String get _displayedText => _displayedTextBuffer.toString();

  Timer? _typeTimer;
  StreamSubscription<String>? _streamSubscription;
  late AnimationController _cursorController;
  bool _isComplete = false;
  bool _isError = false;
  String? _errorMessage;
  final Map<int, AnimationController> _characterAnimations = {};
  final Map<String, List<String>> _rtlGroupCache = {};
  late AnimationController _groupAnimationController;

  @override
  void initState() {
    super.initState();
    _initCursorAnimation();
    _displayedTextBuffer.clear();

    _groupAnimationController = AnimationController(
      vsync: this,
      duration: widget.fadeInDuration,
    );
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
          _displayedTextBuffer.write(data);
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
    if (!mounted || !_fadeInAllowed) return;

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
    // Use accurate word boundary detection for Arabic
    final words = _containsArabic(widget.text)
        ? _splitArabicWords(widget.text)
        : widget.text.split(RegExp(r'\s+'));

    final isRTL = widget.textDirection == TextDirection.rtl ||
        _containsArabic(widget.text);

    int wordIndex = 0;
    _displayedTextBuffer.clear();

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
        final endIndex = (wordIndex + widget.chunkSize).clamp(0, words.length);
        final newWords = words.sublist(wordIndex, endIndex);

        // Write a space if buffer is not empty
        if (_displayedTextBuffer.isNotEmpty) {
          _displayedTextBuffer.write(' ');
        }
        _displayedTextBuffer.writeAll(newWords, ' ');

        if (_fadeInAllowed) {
          final newlyAddedLength = newWords.join(' ').length +
              (newWords.length > 1 ? (newWords.length - 1) : 0);

          if (isRTL) {
            // Animate only the newly added chunk in RTL
            _createRTLWordAnimation(_displayedText, newlyAddedLength);
          } else {
            // Same logic for LTR
            _createCharacterAnimation(
              _displayedText.length - newlyAddedLength,
              newlyAddedLength,
            );
          }
        }

        wordIndex = endIndex;
      });
    });
  }

  List<String> _splitArabicWords(String text) {
    // Split on Arabic word boundaries and spaces
    final words = <String>[];
    final pattern =
        RegExp(r'[\s\u0600-\u060C\u060E-\u061A\u061C-\u061E\u0621\u0640]+');

    int start = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > start) {
        words.add(text.substring(start, match.start));
      }
      start = match.end;
    }

    if (start < text.length) {
      words.add(text.substring(start));
    }

    return words.where((w) => w.trim().isNotEmpty).toList();
  }

  void _createRTLWordAnimation(String text, int newLength) {
    if (!mounted || !_fadeInAllowed) return;

    // --------------------------------------------------------------------------
    // Instead of resetting the groupAnimationController and clearing the map,
    // we'll create local animations for just the newly added characters.
    // --------------------------------------------------------------------------
    final startIndex = text.length - newLength;
    final endIndex = text.length;

    for (int i = startIndex; i < endIndex; i++) {
      // If no animation controller exists for this index, create it
      if (!_characterAnimations.containsKey(i)) {
        final controller = AnimationController(
          vsync: this,
          duration: widget.fadeInDuration,
        );
        _characterAnimations[i] = controller;
        controller.forward(); // Start fade in
      }
    }
  }

  void _startCharacterByCharacterTyping() {
    if (_containsArabic(widget.text)) {
      _startRTLCharacterTyping();
      return;
    }

    final characters = Characters(widget.text).toList();
    int index = 0;

    _displayedTextBuffer.clear();

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
        _displayedTextBuffer.write(chunk);

        if (_fadeInAllowed) {
          _createCharacterAnimation(
            _displayedText.length - currentChunkSize,
            currentChunkSize,
          );
        }
      });

      index += currentChunkSize;
    });
  }

  void _startRTLCharacterTyping() {
    final groups = _getArabicGroups(widget.text);
    int groupIndex = 0;

    _displayedTextBuffer.clear();

    _typeTimer?.cancel();
    _typeTimer = Timer.periodic(widget.typingSpeed, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (groupIndex >= groups.length) {
        timer.cancel();
        setState(() => _isComplete = true);
        widget.onComplete?.call();
        return;
      }

      setState(() {
        if (_displayedTextBuffer.isNotEmpty) {
          _displayedTextBuffer.write(' ');
        }

        final currentGroup = groups[groupIndex];
        _displayedTextBuffer.write(currentGroup);

        if (_fadeInAllowed) {
          _createGroupAnimation(
            groups.sublist(0, groupIndex + 1),
            _displayedText.length - currentGroup.length,
          );
        }
      });

      groupIndex++;
    });
  }

  List<String> _getArabicGroups(String text) {
    if (_rtlGroupCache.containsKey(text)) {
      return _rtlGroupCache[text]!;
    }

    final groups = <String>[];
    final characters = Characters(text).toList();
    String currentGroup = '';

    for (int i = 0; i < characters.length; i++) {
      currentGroup += characters[i];

      // Check if we should split the group
      if (i == characters.length - 1 ||
          _isGroupBreakPoint(characters[i], characters[i + 1])) {
        groups.add(currentGroup);
        currentGroup = '';
      }
    }

    _rtlGroupCache[text] = groups;
    return groups;
  }

  bool _isGroupBreakPoint(String current, String next) {
    // Space or punctuation marks break groups
    return RegExp(r'[\s\u0600-\u060C\u060E-\u061A\u061C-\u061E\u0621\u0640]')
        .hasMatch(current + next);
  }

  void _createGroupAnimation(List<String> groups, int startIndex) {
    if (!mounted || !_fadeInAllowed) return;

    _groupAnimationController.reset();

    // Calculate total width for pre-layout
    int totalLength = groups.fold(0, (sum, group) => sum + group.length);

    // Create single animation for the group
    _characterAnimations.clear();
    for (int i = 0; i < totalLength; i++) {
      _characterAnimations[startIndex + i] = _groupAnimationController;
    }

    _groupAnimationController.forward();
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
        _typeTimer?.cancel();
        setState(() {
          _displayedTextBuffer.clear();
          _displayedTextBuffer.write(widget.text);
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

    // Force RTL alignment for Arabic text
    final effectiveAlignment =
        isRTLText ? TextAlign.right : (widget.textAlign ?? TextAlign.left);

    // If markdown is enabled, wrap with RTL directionality
    if (widget.markdownEnabled) {
      return Directionality(
        textDirection: effectiveTextDirection,
        child: Container(
          width: double.infinity,
          alignment: effectiveAlignment == TextAlign.right
              ? Alignment.centerRight
              : (effectiveAlignment == TextAlign.center
                  ? Alignment.center
                  : Alignment.centerLeft),
          child: MarkdownBody(
            data: _displayedText,
            selectable: widget.selectable,
            styleSheet: widget.markdownStyleSheet ??
                MarkdownStyleSheet.fromTheme(Theme.of(context)),
          ),
        ),
      );
    }

    // For simple text with fade-in animation
    if (_fadeInAllowed) {
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

          // For RTL text, we don't need to reverse the words
          // Let the text direction handle the display order
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

                // Calculate base index for animation
                final baseIndex = isRTL
                    ? _displayedText.length -
                        lines.take(lines.indexOf(line) + 1).join('\n').length +
                        wordIndex
                    : lines.take(lines.indexOf(line)).join('\n').length +
                        words.take(wordIndex).join(' ').length +
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

    // If no controller or fade-in is disallowed, just render static text
    if (controller == null || !_fadeInAllowed) {
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
          // Apply the custom fadeInCurve to the controller's value
          final curveValue = widget.fadeInCurve.transform(controller.value);

          return Transform.translate(
            // Move upward as we approach curveValue = 1
            offset: Offset(0, 10 * (1 - curveValue)),
            child: Opacity(
              // Fade from 0 to 1
              opacity: curveValue,
              child: child,
            ),
          );
        },
        child: Text(text, style: baseStyle),
      ),
    );
  }

  bool _containsArabic(String text) {
    // Improved Arabic detection including all Arabic Unicode ranges
    return RegExp(
            r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]')
        .hasMatch(text);
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _streamSubscription?.cancel();
    _cursorController.dispose();
    _groupAnimationController.dispose();
    _cleanupAnimations();
    super.dispose();
  }
}
