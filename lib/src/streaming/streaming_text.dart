import 'package:flutter/material.dart';
import 'dart:async';
import '../controller/streaming_text_controller.dart';
import '../utils/latex_processor.dart';

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
    this.latexEnabled = false,
    this.latexStyle,
    this.latexScale = 1.0,
    this.latexFadeInEnabled,
    this.fadeInEnabled = false,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.fadeInCurve = Curves.easeOut,
    this.wordByWord = false,
    this.chunkSize = 1,
    this.markdownStyleSheet,
    this.controller,
    this.animationsEnabled = true,
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
  final bool latexEnabled;
  final TextStyle? latexStyle;
  final double latexScale;
  final bool? latexFadeInEnabled;
  final bool fadeInEnabled;
  final Duration fadeInDuration;
  final Curve fadeInCurve;
  final TextStyle? markdownStyleSheet;
  final StreamingTextController? controller;

  /// Whether animations are enabled. When false, text appears instantly.
  final bool animationsEnabled;

  @override
  State<StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<StreamingText>
    with TickerProviderStateMixin {
  // If the text is Arabic, disable fade-in animation.
  bool get _fadeInAllowed {
    // Re-check the actual displayed text for Arabic:
    return widget.animationsEnabled &&
        widget.fadeInEnabled &&
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
  final Map<String, Widget> _markdownCache = {};
  late AnimationController _groupAnimationController;

  // NEW: Advanced State Tracking for Animation Management
  bool _isAnimationActive = false; // Control caching behavior during animation
  final Map<String, Widget> _completeMarkdownCache =
      {}; // Only complete markdown states

  @override
  void initState() {
    super.initState();
    _initCursorAnimation();
    _displayedTextBuffer.clear();

    _groupAnimationController = AnimationController(
      vsync: this,
      duration: widget.fadeInDuration,
    );

    // Set up controller integration
    _setupController();
    _initializeText();
  }

  @override
  void didUpdateWidget(StreamingText oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if configuration changed (requires restart) vs just text changed
    final configChanged = _hasConfigurationChanged(oldWidget);

    if (configChanged) {
      // Configuration changed - restart animation completely
      _restartAnimation();
    } else if (widget.text != oldWidget.text && !widget.animationsEnabled) {
      // Animations disabled - show text instantly
      _displayInstantText();
    } else if (widget.text != oldWidget.text &&
        widget.text.startsWith(oldWidget.text)) {
      // Text was appended - continue animation from where we left off
      _continueAnimationFromTextAppend(oldWidget.text, widget.text);
    } else if (widget.text != oldWidget.text) {
      // Text changed but not appended - restart animation
      _restartAnimation();
    }
  }

  bool _hasConfigurationChanged(StreamingText oldWidget) {
    return widget.typingSpeed != oldWidget.typingSpeed ||
        widget.wordByWord != oldWidget.wordByWord ||
        widget.chunkSize != oldWidget.chunkSize ||
        widget.fadeInEnabled != oldWidget.fadeInEnabled ||
        widget.fadeInDuration != oldWidget.fadeInDuration ||
        widget.fadeInCurve != oldWidget.fadeInCurve ||
        widget.markdownEnabled != oldWidget.markdownEnabled ||
        widget.latexEnabled != oldWidget.latexEnabled ||
        widget.animationsEnabled != oldWidget.animationsEnabled;
  }

  void _displayInstantText() {
    _typeTimer?.cancel();
    setState(() {
      _displayedTextBuffer.clear();
      _displayedTextBuffer.write(widget.text);
      _isComplete = true;
      _isAnimationActive = false;
    });
    widget.controller?.markCompleted();
    widget.onComplete?.call();
  }

  void _continueAnimationFromTextAppend(String oldText, String newText) {
    if (!widget.animationsEnabled) {
      _displayInstantText();
      return;
    }

    // Cancel current typing timer
    _typeTimer?.cancel();
    _typeTimer = null;

    // Reset completion state since we have more text to animate
    setState(() {
      _isComplete = false;
      _isAnimationActive = true;
    });

    // The key insight: We need to continue from where we left off in the OLD text,
    // then animate the appended portion
    final currentProgress = _displayedText.length;
    final appendedText = newText.substring(oldText.length);

    // If we're still animating the original text portion, continue that first
    if (currentProgress < oldText.length) {
      if (widget.wordByWord) {
        _resumeWordByWordTypingFromOldText(oldText, appendedText);
      } else {
        _resumeCharacterByCharacterTypingFromOldText(oldText, appendedText);
      }
    } else {
      // We finished the old text, now animate just the appended portion
      _animateAppendedText(appendedText);
    }
  }

  void _animateAppendedText(String appendedText) {
    if (appendedText.isEmpty) {
      setState(() {
        _isComplete = true;
        _isAnimationActive = false;
      });
      widget.controller?.markCompleted();
      widget.onComplete?.call();
      return;
    }

    List<String> appendedUnits;
    if (widget.latexEnabled && LaTeXProcessor.containsLaTeX(appendedText)) {
      // Handle LaTeX in appended text
      final segments = LaTeXProcessor.parseTextSegments(appendedText);
      appendedUnits = [];
      for (final segment in segments) {
        if (segment.isLaTeX) {
          appendedUnits.add(segment.content); // Add LaTeX as single unit
        } else {
          if (widget.wordByWord) {
            appendedUnits.addAll(segment.content.split(RegExp(r'\s+')));
          } else {
            appendedUnits.addAll(Characters(segment.content).toList());
          }
        }
      }
    } else {
      appendedUnits = widget.wordByWord
          ? appendedText.split(RegExp(r'\s+'))
          : Characters(appendedText).toList();
    }

    int index = 0;
    _typeTimer = Timer.periodic(widget.typingSpeed, (timer) {
      if (!mounted || index >= appendedUnits.length) {
        timer.cancel();
        setState(() {
          _isComplete = true;
          _isAnimationActive = false;
        });
        widget.controller?.markCompleted();
        widget.onComplete?.call();
        return;
      }

      setState(() {
        _displayedTextBuffer.write(appendedUnits[index]);
        index++;
        _updateProgress();
      });
    });
  }

  void _setupController() {
    if (widget.controller != null) {
      widget.controller!.updateState(StreamingTextState.idle);
      // Listen for controller commands
      widget.controller!.addListener(_handleControllerChange);
    }
  }

  void _handleControllerChange() {
    if (widget.controller == null || !mounted) return;

    final controller = widget.controller!;

    // Handle pause/resume
    if (controller.isPaused && _typeTimer?.isActive == true) {
      _typeTimer?.cancel();
    } else if (!controller.isPaused &&
        controller.state == StreamingTextState.animating &&
        _typeTimer?.isActive != true) {
      _resumeAnimation();
    }

    // Handle restart
    if (controller.state == StreamingTextState.animating &&
        controller.progress == 0.0 &&
        _displayedText.isNotEmpty) {
      _restartAnimation();
    }

    // Handle skip to end
    if (controller.state == StreamingTextState.completed && !_isComplete) {
      _skipToEnd();
    }
  }

  void _resumeAnimation() {
    if (widget.wordByWord) {
      _resumeWordByWordTyping();
    } else {
      _resumeCharacterByCharacterTyping();
    }
  }

  void _restartAnimation() {
    _typeTimer?.cancel();
    setState(() {
      _displayedTextBuffer.clear();
      _isComplete = false;
      _isAnimationActive = true;
      _completeMarkdownCache.clear(); // Clear cache on restart
      _cleanupAnimations();
    });
    _initializeText();
  }

  void _skipToEnd() {
    _typeTimer?.cancel();
    setState(() {
      _displayedTextBuffer.clear();
      _displayedTextBuffer.write(widget.text);
      _isComplete = true;
      _isAnimationActive = false;
    });
    widget.controller?.markCompleted();
    widget.onComplete?.call();
    // Force rebuild to process complete markdown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
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
    // If animations are disabled, show text instantly
    if (!widget.animationsEnabled) {
      _displayInstantText();
      return;
    }

    widget.controller?.updateState(StreamingTextState.animating);

    // Initialize state tracking
    _isAnimationActive = true;
    _completeMarkdownCache.clear(); // Clear cache when starting new animation

    if (widget.stream != null) {
      _handleStream();
    } else {
      _startTyping();
    }
  }

  void _resumeWordByWordTyping() {
    // Resume word-by-word typing from current position
    if (_isComplete) return;

    List<String> units;
    if (widget.latexEnabled && LaTeXProcessor.containsLaTeX(widget.text)) {
      units = _parseTextUnitsWithLatex();
    } else {
      units = _containsArabic(widget.text)
          ? _splitArabicWords(widget.text)
          : _splitMarkdownAwareWords(widget.text);
    }

    // Calculate current position based on displayed text length
    int currentUnitIndex = 0;
    int displayedLength = 0;

    for (int i = 0; i < units.length; i++) {
      final unit = units[i];
      final unitLength =
          unit == '\n' ? 1 : unit.length + (i > 0 ? 1 : 0); // +1 for space
      if (displayedLength + unitLength > _displayedText.length) {
        break;
      }
      displayedLength += unitLength;
      currentUnitIndex = i + 1;
    }

    _startWordByWordTypingFromIndex(units, currentUnitIndex);
  }

  void _resumeCharacterByCharacterTyping() {
    // Resume character-by-character typing from current position
    if (_isComplete) return;

    List<String> units;
    if (widget.latexEnabled && LaTeXProcessor.containsLaTeX(widget.text)) {
      units = _parseCharacterUnitsWithLatex();
    } else {
      units = Characters(widget.text).toList();
    }

    final currentIndex = _displayedText.length;
    _startCharacterByCharacterTypingFromIndex(units, currentIndex);
  }

  void _resumeCharacterByCharacterTypingFromOldText(
      String oldText, String appendedText) {
    if (_isComplete) return;

    // Parse units for the OLD text only
    List<String> oldTextUnits;
    if (widget.latexEnabled && LaTeXProcessor.containsLaTeX(oldText)) {
      final segments = LaTeXProcessor.parseTextSegments(oldText);
      oldTextUnits = [];
      for (final segment in segments) {
        if (segment.isLaTeX) {
          oldTextUnits.add(segment.content);
        } else {
          oldTextUnits.addAll(Characters(segment.content).toList());
        }
      }
    } else {
      oldTextUnits = Characters(oldText).toList();
    }

    final currentIndex = _displayedText.length;

    // Continue animating the old text first, then the appended text
    _startCharacterByCharacterTypingFromIndexWithContinuation(
        oldTextUnits, currentIndex, appendedText);
  }

  void _resumeWordByWordTypingFromOldText(String oldText, String appendedText) {
    // Similar logic for word-by-word mode
    if (_isComplete) return;

    // For now, fall back to character mode - we can implement word mode later
    _resumeCharacterByCharacterTypingFromOldText(oldText, appendedText);
  }

  void _updateProgress() {
    if (widget.controller != null && widget.text.isNotEmpty) {
      final progress = _displayedText.length / widget.text.length;
      widget.controller!.updateProgress(progress);
    }
  }

  void _handleStream() {
    _streamSubscription?.cancel();
    final broadcastStream = widget.stream!.asBroadcastStream();
    _streamSubscription = broadcastStream.listen(
      (data) {
        setState(() {
          final previousLength = _displayedText.length;
          _displayedTextBuffer.write(data);
          _isError = false;
          _errorMessage = null;

          // FIXED: Continue animation from last position instead of restarting
          if (_isAnimationActive && previousLength > 0) {
            _continueAnimationFrom(previousLength);
          } else if (!_isAnimationActive) {
            // Start new animation if none is active
            _isAnimationActive = true;
            _startAnimationFrom(previousLength);
          }

          _updateProgress();
        });
      },
      onError: (error) {
        setState(() {
          _isError = true;
          _errorMessage = error.toString();
        });
      },
      onDone: () {
        setState(() {
          _isComplete = true;
          _isAnimationActive = false;
        });
        widget.controller?.markCompleted();
        widget.onComplete?.call();
        // Force rebuild to process complete markdown
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      },
    );
  }

  void _continueAnimationFrom(int startIndex) {
    // Only animate newly added content from the specified index
    final newContent = _displayedText.substring(startIndex);
    if (newContent.isNotEmpty && !_isComplete) {
      // Update the animation to continue from where it left off

      // Continue with the existing typing animation logic
      // The existing timers will handle the new content
    }
  }

  void _startAnimationFrom(int startIndex) {
    // Start animation from specified index
    if (!_isComplete) {
      _startTyping();
    }
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
    List<String> units;

    // If LaTeX is enabled, parse text into segments that preserve LaTeX expressions
    if (widget.latexEnabled && LaTeXProcessor.containsLaTeX(widget.text)) {
      units = _parseTextUnitsWithLatex();
    } else {
      // Use markdown-aware word splitting for better formatting
      units = _containsArabic(widget.text)
          ? _splitArabicWords(widget.text)
          : _splitMarkdownAwareWords(widget.text);
    }

    final isRTL = widget.textDirection == TextDirection.rtl ||
        _containsArabic(widget.text);

    int unitIndex = 0;
    _displayedTextBuffer.clear();

    _typeTimer?.cancel();
    _typeTimer = Timer.periodic(widget.typingSpeed, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (unitIndex >= units.length) {
        timer.cancel();
        setState(() {
          _isComplete = true;
          _isAnimationActive = false; // Animation is now complete
        });
        widget.controller?.markCompleted();
        widget.onComplete?.call();
        // Force rebuild to process complete markdown
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
        return;
      }

      setState(() {
        final endIndex = (unitIndex + widget.chunkSize).clamp(0, units.length);
        final newUnits = units.sublist(unitIndex, endIndex);

        for (final unit in newUnits) {
          if (unit == '\n') {
            // Handle newlines directly
            _displayedTextBuffer.write('\n');
          } else if (unit.startsWith('#')) {
            // Headers should be on their own line
            if (_displayedTextBuffer.isNotEmpty &&
                !_displayedTextBuffer.toString().endsWith('\n')) {
              _displayedTextBuffer.write('\n');
            }
            _displayedTextBuffer.write(unit);
            _displayedTextBuffer.write('\n');
          } else {
            // Regular words - add space before if needed
            if (_displayedTextBuffer.isNotEmpty &&
                !_displayedTextBuffer.toString().endsWith(' ') &&
                !_displayedTextBuffer.toString().endsWith('\n')) {
              _displayedTextBuffer.write(' ');
            }
            _displayedTextBuffer.write(unit);
          }
        }

        if (_fadeInAllowed &&
            !(widget.latexEnabled && _containsLatexInUnits(newUnits))) {
          final newlyAddedLength = newUnits.join(' ').length +
              (newUnits.length > 1 ? (newUnits.length - 1) : 0);

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

        unitIndex = endIndex;
        _updateProgress();
      });
    });
  }

  void _startWordByWordTypingFromIndex(List<String> units, int startIndex) {
    int unitIndex = startIndex;

    _typeTimer?.cancel();
    _typeTimer = Timer.periodic(widget.typingSpeed, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (unitIndex >= units.length) {
        timer.cancel();
        setState(() {
          _isComplete = true;
          _isAnimationActive = false;
        });
        widget.controller?.markCompleted();
        widget.onComplete?.call();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
        return;
      }

      setState(() {
        final endIndex = (unitIndex + widget.chunkSize).clamp(0, units.length);
        final newUnits = units.sublist(unitIndex, endIndex);

        for (final unit in newUnits) {
          if (unit == '\n') {
            _displayedTextBuffer.write('\n');
          } else if (unit.startsWith('#')) {
            if (_displayedTextBuffer.isNotEmpty &&
                !_displayedTextBuffer.toString().endsWith('\n')) {
              _displayedTextBuffer.write('\n');
            }
            _displayedTextBuffer.write(unit);
            _displayedTextBuffer.write('\n');
          } else {
            if (_displayedTextBuffer.isNotEmpty &&
                !_displayedTextBuffer.toString().endsWith(' ') &&
                !_displayedTextBuffer.toString().endsWith('\n')) {
              _displayedTextBuffer.write(' ');
            }
            _displayedTextBuffer.write(unit);
          }
        }

        unitIndex = endIndex;
        _updateProgress();
      });
    });
  }

  void _startCharacterByCharacterTypingFromIndexWithContinuation(
      List<String> oldTextUnits, int startIndex, String appendedText) {
    int index = startIndex;

    _typeTimer?.cancel();
    _typeTimer = Timer.periodic(widget.typingSpeed, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (index >= oldTextUnits.length) {
        // Finished animating the old text, now animate the appended portion
        timer.cancel();
        _animateAppendedText(appendedText);
        return;
      }

      final chunkSize = widget.chunkSize;
      final remainingUnits = oldTextUnits.length - index;
      final currentChunkSize =
          chunkSize > remainingUnits ? remainingUnits : chunkSize;

      setState(() {
        for (int i = 0; i < currentChunkSize; i++) {
          if (index < oldTextUnits.length) {
            _displayedTextBuffer.write(oldTextUnits[index]);
            index++;
            _updateProgress();
          }
        }
      });
    });
  }

  void _startCharacterByCharacterTypingFromIndex(
      List<String> units, int startIndex) {
    int index = startIndex;

    _typeTimer?.cancel();
    _typeTimer = Timer.periodic(widget.typingSpeed, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (index >= units.length) {
        timer.cancel();
        setState(() {
          _isComplete = true;
          _isAnimationActive = false;
        });
        widget.controller?.markCompleted();
        widget.onComplete?.call();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
        return;
      }

      final chunkSize = widget.chunkSize;
      final remainingUnits = units.length - index;
      final currentChunkSize =
          chunkSize > remainingUnits ? remainingUnits : chunkSize;

      setState(() {
        final chunk = units.getRange(index, index + currentChunkSize).join();
        _displayedTextBuffer.write(chunk);
        _updateProgress();
      });

      index += currentChunkSize;
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

  List<String> _splitMarkdownAwareWords(String text) {
    final words = <String>[];
    final lines = text.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Handle headers as single units to preserve formatting
      if (line.startsWith('### ') ||
          line.startsWith('## ') ||
          line.startsWith('# ')) {
        words.add(line);
      } else if (line.trim().isEmpty) {
        // Preserve empty lines
        words.add(line);
      } else {
        // Split regular text by spaces, but preserve markdown syntax
        final lineWords = line.split(RegExp(r'\s+'));
        words.addAll(lineWords.where((w) => w.isNotEmpty));
      }

      // Add line break marker except for last line
      if (i < lines.length - 1) {
        words.add('\n');
      }
    }

    return words;
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

    List<String> units;

    // If LaTeX is enabled, use character units that preserve LaTeX expressions
    if (widget.latexEnabled && LaTeXProcessor.containsLaTeX(widget.text)) {
      units = _parseCharacterUnitsWithLatex();
    } else {
      // Regular character-by-character processing
      units = Characters(widget.text).toList();
    }

    int index = 0;
    _displayedTextBuffer.clear();

    _typeTimer?.cancel();
    _typeTimer = Timer.periodic(widget.typingSpeed, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (index >= units.length) {
        timer.cancel();
        setState(() {
          _isComplete = true;
          _isAnimationActive = false; // Animation is now complete
        });
        widget.controller?.markCompleted();
        widget.onComplete?.call();
        // Force rebuild to process complete markdown
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
        return;
      }

      final chunkSize = widget.chunkSize;
      final remainingUnits = units.length - index;
      final currentChunkSize =
          chunkSize > remainingUnits ? remainingUnits : chunkSize;

      setState(() {
        final chunk = units.getRange(index, index + currentChunkSize).join();
        _displayedTextBuffer.write(chunk);

        // Don't animate LaTeX content with fade-in for performance
        if (_fadeInAllowed &&
            !(widget.latexEnabled &&
                _containsLatexInUnits(units
                    .getRange(index, index + currentChunkSize)
                    .toList()))) {
          _createCharacterAnimation(
            _displayedText.length - chunk.length,
            chunk.length,
          );
        }

        _updateProgress();
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
        setState(() {
          _isComplete = true;
          _isAnimationActive = false;
        });
        widget.onComplete?.call();
        // Force rebuild to process complete markdown
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
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
          _isAnimationActive = false;
        });
        widget.onComplete?.call();
        // Force rebuild to process complete markdown
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
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
          child: _buildMarkdownBody(),
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

  /// Parses text into units that preserve LaTeX expressions as atomic blocks
  List<String> _parseTextUnitsWithLatex() {
    final segments = LaTeXProcessor.parseTextSegments(widget.text);
    final units = <String>[];

    for (final segment in segments) {
      if (segment.isLaTeX) {
        // LaTeX expressions are treated as single atomic units
        units.add(segment.fullExpression);
      } else {
        // Regular text is split into words
        final words = _containsArabic(segment.content)
            ? _splitArabicWords(segment.content)
            : segment.content.split(RegExp(r'\s+'));
        units.addAll(words.where((w) => w.trim().isNotEmpty));
      }
    }

    return units;
  }

  /// Checks if any of the units contains LaTeX expressions
  bool _containsLatexInUnits(List<String> units) {
    return units.any((unit) => LaTeXProcessor.containsLaTeX(unit));
  }

  /// Parses text into character units that preserve LaTeX expressions as atomic blocks
  List<String> _parseCharacterUnitsWithLatex() {
    final segments = LaTeXProcessor.parseTextSegments(widget.text);
    final units = <String>[];

    for (final segment in segments) {
      if (segment.isLaTeX) {
        // LaTeX expressions are treated as single atomic units
        units.add(segment.fullExpression);
      } else {
        // Regular text is split into individual characters
        final characters = Characters(segment.content).toList();
        units.addAll(characters);
      }
    }

    return units;
  }

  Widget _buildMarkdownBody() {
    // Only use LaTeX processing if LaTeX is enabled AND LaTeX content is actually present
    if (widget.latexEnabled && LaTeXProcessor.containsLaTeX(_displayedText)) {
      // Process LaTeX expressions and render them properly
      return _buildLatexMarkdown();
    } else {
      // Standard markdown rendering for content without LaTeX
      return _buildSimpleMarkdown();
    }
  }

  Widget _buildLatexMarkdown() {
    // Parse text segments and build widgets for each
    final segments = LaTeXProcessor.parseTextSegments(_displayedText);

    if (segments.isEmpty) {
      return const SizedBox.shrink();
    }

    // For now, we'll render LaTeX as styled text with a math-like appearance
    // This is a simplified approach that works without external LaTeX renderers
    final children = <Widget>[];

    for (final segment in segments) {
      if (segment.isLaTeX) {
        // Render LaTeX content with special styling
        children.add(
          Container(
            padding: segment.type == SegmentType.blockLaTeX
                ? const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0)
                : const EdgeInsets.symmetric(horizontal: 4.0),
            margin: segment.type == SegmentType.blockLaTeX
                ? const EdgeInsets.symmetric(vertical: 8.0)
                : EdgeInsets.zero,
            decoration: segment.type == SegmentType.blockLaTeX
                ? BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.2),
                    ),
                  )
                : null,
            child: SelectableText(
              _formatLatexForDisplay(segment.content),
              style: (widget.latexStyle ?? widget.style ?? const TextStyle())
                  .copyWith(
                fontFamily: 'monospace',
                fontSize: (widget.latexStyle?.fontSize ??
                        widget.style?.fontSize ??
                        14) *
                    widget.latexScale,
                color: widget.latexStyle?.color ?? Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      } else {
        // Render regular markdown content using simple markdown parser
        if (segment.content.trim().isNotEmpty) {
          children.add(
            _buildFormattedText(segment.content),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildSimpleMarkdown() {
    if (!widget.markdownEnabled) {
      return Text(
        _displayedText,
        style: widget.style,
      );
    }

    final currentText = _displayedText;

    // FIXED: Only use cache when animation is complete and content hasn't changed
    if (!_isAnimationActive &&
        _isComplete &&
        _completeMarkdownCache.containsKey(currentText)) {
      return _completeMarkdownCache[currentText]!;
    }

    // Quick check: if text looks like it has no markdown, show as plain text
    if (!_looksLikeMarkdown(currentText)) {
      final widget = Text(currentText, style: this.widget.style);

      // Cache only if animation is complete
      if (!_isAnimationActive && _isComplete) {
        _completeMarkdownCache[currentText] = widget;
      }

      return widget;
    }

    // Build markdown content - progressive during animation, complete when done
    final result = _isAnimationActive
        ? _buildProgressiveMarkdown(currentText)
        : _buildCompleteMarkdown(currentText);

    // Cache only complete, final states
    if (!_isAnimationActive && _isComplete) {
      _completeMarkdownCache[currentText] = result;
    }

    return result;
  }

  bool _looksLikeMarkdown(String text) {
    // Quick checks to avoid expensive processing
    return text.contains('#') || text.contains('**') || text.contains('*');
  }

  Widget _buildProgressiveMarkdown(String text) {
    // During animation, build markdown progressively without heavy caching
    // This allows the UI to update smoothly during animation
    return _processMarkdownLines();
  }

  Widget _buildCompleteMarkdown(String text) {
    // When animation is complete, build the final markdown with full processing
    return _processMarkdownLines();
  }

  Widget _processMarkdownLines() {
    final lines = _displayedText.split('\n');
    final children = <Widget>[];

    for (final line in lines) {
      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 8));
        continue;
      }

      // Headers - only process if complete
      if (line.startsWith('### ') && line.length > 4) {
        children.add(Text(
          line.substring(4),
          style: (widget.style ?? const TextStyle()).copyWith(
            fontSize: (widget.style?.fontSize ?? 16) * 1.2,
            fontWeight: FontWeight.w600,
          ),
        ));
      } else if (line.startsWith('## ') && line.length > 3) {
        children.add(Text(
          line.substring(3),
          style: (widget.style ?? const TextStyle()).copyWith(
            fontSize: (widget.style?.fontSize ?? 16) * 1.4,
            fontWeight: FontWeight.w700,
          ),
        ));
      } else if (line.startsWith('# ') && line.length > 2) {
        children.add(Text(
          line.substring(2),
          style: (widget.style ?? const TextStyle()).copyWith(
            fontSize: (widget.style?.fontSize ?? 16) * 1.6,
            fontWeight: FontWeight.w800,
          ),
        ));
      } else {
        // Only process inline formatting if line contains markdown markers
        if (line.contains('**') || line.contains('*')) {
          children.add(_buildFormattedText(line));
        } else {
          children.add(Text(line, style: widget.style));
        }
      }

      children.add(const SizedBox(height: 4));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildFormattedText(String text) {
    final baseStyle = widget.style ?? const TextStyle();

    // Performance: Simple string operations instead of complex regex
    final spans = <TextSpan>[];
    int currentIndex = 0;

    while (currentIndex < text.length) {
      // Look for bold patterns **text**
      final boldStart = text.indexOf('**', currentIndex);
      if (boldStart != -1) {
        final boldEnd = text.indexOf('**', boldStart + 2);
        if (boldEnd != -1) {
          // Add text before bold
          if (boldStart > currentIndex) {
            spans.add(TextSpan(
              text: text.substring(currentIndex, boldStart),
              style: baseStyle,
            ));
          }
          // Add bold text
          spans.add(TextSpan(
            text: text.substring(boldStart + 2, boldEnd),
            style: baseStyle.copyWith(fontWeight: FontWeight.bold),
          ));
          currentIndex = boldEnd + 2;
          continue;
        }
      }

      // Look for italic patterns *text* (not part of bold)
      final italicStart = text.indexOf('*', currentIndex);
      if (italicStart != -1 &&
          (italicStart == 0 || text[italicStart - 1] != '*') &&
          (italicStart + 1 < text.length && text[italicStart + 1] != '*')) {
        final italicEnd = text.indexOf('*', italicStart + 1);
        if (italicEnd != -1 &&
            (italicEnd + 1 >= text.length || text[italicEnd + 1] != '*')) {
          // Add text before italic
          if (italicStart > currentIndex) {
            spans.add(TextSpan(
              text: text.substring(currentIndex, italicStart),
              style: baseStyle,
            ));
          }
          // Add italic text
          spans.add(TextSpan(
            text: text.substring(italicStart + 1, italicEnd),
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          ));
          currentIndex = italicEnd + 1;
          continue;
        }
      }

      // No more patterns found, add remaining text
      spans.add(TextSpan(
        text: text.substring(currentIndex),
        style: baseStyle,
      ));
      break;
    }

    return spans.isEmpty
        ? Text(text, style: baseStyle)
        : Text.rich(TextSpan(children: spans));
  }

  String _formatLatexForDisplay(String latex) {
    // Simple LaTeX to Unicode conversion for better display
    return latex
        .replaceAll(r'\alpha', 'α')
        .replaceAll(r'\beta', 'β')
        .replaceAll(r'\gamma', 'γ')
        .replaceAll(r'\delta', 'δ')
        .replaceAll(r'\pi', 'π')
        .replaceAll(r'\sigma', 'σ')
        .replaceAll(r'\lambda', 'λ')
        .replaceAll(r'\mu', 'μ')
        .replaceAll(r'\theta', 'θ')
        .replaceAll(r'\phi', 'φ')
        .replaceAll(r'\psi', 'ψ')
        .replaceAll(r'\omega', 'ω')
        .replaceAll(r'\pm', '±')
        .replaceAll(r'\mp', '∓')
        .replaceAll(r'\times', '×')
        .replaceAll(r'\div', '÷')
        .replaceAll(r'\cdot', '·')
        .replaceAll(r'\neq', '≠')
        .replaceAll(r'\leq', '≤')
        .replaceAll(r'\geq', '≥')
        .replaceAll(r'\approx', '≈')
        .replaceAll(r'\equiv', '≡')
        .replaceAll(r'\infty', '∞')
        .replaceAll(r'\sum', '∑')
        .replaceAll(r'\int', '∫')
        .replaceAll(r'\partial', '∂')
        .replaceAll(r'\nabla', '∇')
        .replaceAll(r'\sqrt', '√')
        .replaceAll(r'\ldots', '…')
        .replaceAll(r'\rightarrow', '→')
        .replaceAll(r'\leftarrow', '←')
        .replaceAll(r'\Rightarrow', '⇒')
        .replaceAll(r'\Leftarrow', '⇐')
        .replaceAll(r'\hbar', 'ℏ')
        // Handle fractions
        .replaceAllMapped(RegExp(r'\\frac\{([^}]*)\}\{([^}]*)\}'), (match) {
          return '${match.group(1)}/${match.group(2)}';
        })
        // Handle superscripts (simplified)
        .replaceAllMapped(RegExp(r'\^(\w|\{[^}]*\})'), (match) {
          final exp = match.group(1)!.replaceAll(RegExp(r'[{}]'), '');
          return '^$exp';
        })
        // Handle subscripts (simplified)
        .replaceAllMapped(RegExp(r'_(\w|\{[^}]*\})'), (match) {
          final sub = match.group(1)!.replaceAll(RegExp(r'[{}]'), '');
          return '₍$sub₎';
        })
        // Clean up remaining LaTeX commands
        .replaceAll(RegExp(r'\\[a-zA-Z]+'), '')
        .replaceAll(RegExp(r'[{}]'), '');
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _streamSubscription?.cancel();
    _cursorController.dispose();
    _groupAnimationController.dispose();
    _cleanupAnimations();

    // Clear caches to prevent memory leaks
    _markdownCache.clear();
    _completeMarkdownCache.clear();
    _rtlGroupCache.clear();

    // Remove controller listener
    if (widget.controller != null) {
      widget.controller!.removeListener(_handleControllerChange);
    }

    super.dispose();
  }
}
