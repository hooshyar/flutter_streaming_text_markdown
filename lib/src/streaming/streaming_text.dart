import 'package:flutter/material.dart';
import 'dart:async';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
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
    this.trailingFadeEnabled = false,
    this.imageBuilder,
    this.onLinkTap,
    this.codeBuilder,
    this.latexBuilder,
    this.sourceTagBuilder,
    this.highlightBuilder,
    this.linkBuilder,
    this.components,
    this.inlineComponents,
    this.completeAnimationOnTap = true,
    this.onTextChanged,
  });

  /// The text to display. Ignored as the initial source when [stream] is set
  /// (the stream drives content instead).
  final String text;

  /// How long to wait between revealing each character (or word/chunk,
  /// depending on [wordByWord] and [chunkSize]).
  final Duration typingSpeed;

  /// Whether to reveal text one word at a time instead of one character (or
  /// [chunkSize] characters) at a time.
  final bool wordByWord;

  /// The number of characters revealed per animation tick when [wordByWord]
  /// is `false`. Ignored in word-by-word mode.
  final int chunkSize;

  /// Text style applied to the rendered content.
  final TextStyle? style;

  /// Strut style forwarded to the underlying text rendering.
  final StrutStyle? strutStyle;

  /// Horizontal alignment of the rendered text.
  final TextAlign? textAlign;

  /// Text direction override. When `null`, direction is inferred (including
  /// automatic RTL detection for Arabic content).
  final TextDirection? textDirection;

  /// Locale used for text rendering and layout.
  final Locale? locale;

  /// Whether the text should break at soft line breaks.
  final bool? softWrap;

  /// How visual overflow should be handled.
  final TextOverflow? overflow;

  /// Scales the rendered text size.
  final TextScaler? textScaler;

  /// Maximum number of lines to display before truncating/overflowing.
  final int? maxLines;

  /// Semantic label used for accessibility.
  final String? semanticsLabel;

  /// How to measure the width of the rendered text.
  final TextWidthBasis? textWidthBasis;

  /// Height behavior applied to the rendered text.
  final TextHeightBehavior? textHeightBehavior;

  /// Whether the rendered text can be selected by the user.
  final bool selectable;

  /// Whether to show a blinking cursor at the end of the text while
  /// animating.
  final bool showCursor;

  /// Color of the blinking cursor shown while [showCursor] is `true`.
  final Color? cursorColor;

  /// Called once the animation (or stream) finishes.
  final VoidCallback? onComplete;

  /// Optional stream of text chunks. When provided, [text] is ignored as the
  /// initial source and content arrives via the stream instead.
  ///
  /// Note: per-character [fadeInEnabled] is automatically suppressed when a
  /// stream is set — animating one [AnimationController] per glyph on an
  /// unbounded stream causes memory and frame-rate issues. For a smooth reveal
  /// on streaming content, use [trailingFadeEnabled] instead.
  final Stream<String>? stream;

  /// Whether to render [text] as markdown (headers, bold, lists, etc.) via
  /// `gpt_markdown` instead of as plain text.
  final bool markdownEnabled;

  /// Whether to parse and render LaTeX expressions (`$...$` and `$$...$$`).
  final bool latexEnabled;

  /// Text style applied to rendered LaTeX expressions.
  final TextStyle? latexStyle;

  /// Scale factor applied to rendered LaTeX expressions.
  final double latexScale;

  /// Whether LaTeX content fades in as it's revealed. Defaults to matching
  /// [fadeInEnabled] when `null`; disabled by default for performance.
  final bool? latexFadeInEnabled;

  /// Whether each character (or word, in word-by-word mode) fades in as it is
  /// revealed.
  ///
  /// **Disabled automatically** when:
  /// - [stream] is non-null (use [trailingFadeEnabled] for streams)
  /// - The displayed text contains Arabic — RTL Unicode ranges trigger an
  ///   automatic fallback for performance
  ///
  /// Defaults to `false`.
  final bool fadeInEnabled;

  /// How long each character's/word's fade-in animation takes.
  final Duration fadeInDuration;

  /// The animation curve used for the fade-in effect.
  final Curve fadeInCurve;

  /// Text style passed through to the markdown renderer.
  final TextStyle? markdownStyleSheet;

  /// Optional controller for programmatic pause/resume/restart/skip control
  /// and progress tracking.
  final StreamingTextController? controller;

  /// Whether animations are enabled. When false, text appears instantly.
  final bool animationsEnabled;

  /// Whether to show a trailing gradient fade at the bottom edge while text is
  /// streaming. The fade animates away when streaming completes (using
  /// [fadeInDuration] / [fadeInCurve] for the dismiss animation).
  ///
  /// Recommended for stream-based usage where [fadeInEnabled] is suppressed.
  /// Works alongside [markdownEnabled] and RTL/Arabic content.
  ///
  /// Defaults to `false`.
  final bool trailingFadeEnabled;

  /// Custom builder for images in markdown content.
  final Widget Function(BuildContext context, String imageUrl)? imageBuilder;

  /// Callback when a link is tapped in markdown content.
  final void Function(String url, String title)? onLinkTap;

  /// Custom builder for code blocks in markdown content.
  final Widget Function(
      BuildContext context, String name, String code, bool closed)? codeBuilder;

  /// Custom builder for LaTeX expressions in markdown content.
  final Widget Function(
          BuildContext context, String tex, TextStyle textStyle, bool inline)?
      latexBuilder;

  /// Custom builder for source tags in markdown content.
  final Widget Function(
          BuildContext context, String content, TextStyle textStyle)?
      sourceTagBuilder;

  /// Custom builder for highlighted text in markdown content.
  final Widget Function(BuildContext context, String text, TextStyle style)?
      highlightBuilder;

  /// Custom builder for links in markdown content.
  final Widget Function(
          BuildContext context, InlineSpan text, String url, TextStyle style)?
      linkBuilder;

  /// Custom block-level markdown components. Forwarded as-is to
  /// `gpt_markdown`'s `GptMarkdown.components`. Use this to override how
  /// headers, lists, bold, italic, tables, etc. are rendered. When `null`,
  /// `gpt_markdown`'s default component list is used.
  final List<MarkdownComponent>? components;

  /// Custom inline markdown components. Forwarded as-is to
  /// `gpt_markdown`'s `GptMarkdown.inlineComponents`. When `null`,
  /// `gpt_markdown`'s default inline component list is used.
  final List<MarkdownComponent>? inlineComponents;

  /// Whether tapping the widget jumps the animation to completion.
  ///
  /// Defaults to `true`. Set to `false` to let the animation play through
  /// uninterrupted regardless of taps.
  final bool completeAnimationOnTap;

  /// v1.9.1 slice 5: internal hook fired whenever the displayed text buffer
  /// grows during animation/streaming (i.e. from inside `_updateProgress`).
  /// Not part of the public [StreamingTextMarkdown] API surface directly —
  /// used internally to drive auto-scroll pinning while content grows, rather
  /// than only once at completion. Optional and defaults to `null` so this
  /// stays fully backward-compatible for any external consumer of
  /// [StreamingText] (exported via `streaming.dart`).
  final VoidCallback? onTextChanged;

  @override
  State<StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<StreamingText>
    with TickerProviderStateMixin {
  // If the text is Arabic, disable fade-in animation (per-character path).
  bool get _fadeInAllowed {
    // Re-check the actual displayed text for Arabic:
    return widget.animationsEnabled &&
        widget.fadeInEnabled &&
        widget.stream == null &&
        !_containsArabic(_displayedText);
  }

  /// Whether markdown-compatible trailing-edge fade is allowed.
  /// Controlled by [trailingFadeEnabled], independent of [fadeInEnabled].
  /// Stays true while the fade-out animation is still playing after completion.
  bool get _markdownFadeAllowed {
    return widget.animationsEnabled &&
        widget.trailingFadeEnabled &&
        widget.markdownEnabled &&
        (!_isComplete || _groupAnimationController.value < 1.0);
  }

  /// Triggers the trailing-edge fade animation for streaming content.
  /// While streaming is active, the fade stays applied (controller at 0).
  /// When streaming completes, the fade animates away (controller goes to 1).
  void _triggerTrailingFade() {
    if (!mounted || !widget.animationsEnabled || !widget.trailingFadeEnabled) {
      return;
    }
    if (_isComplete) {
      // Streaming finished — animate the trailing fade away smoothly
      if (!_groupAnimationController.isAnimating) {
        _groupAnimationController.forward();
      }
    }
    // While streaming, controller stays at 0 (set in initState) — no action needed
  }

  /// Centralized completion hook. Fires the user's onComplete callback and
  /// dismisses the trailing-edge fade. Call after `_isComplete` is set to true.
  /// Does NOT call controller.markCompleted — that's not idempotent and stays
  /// at the call sites that need it.
  void _handleCompletion() {
    widget.onComplete?.call();
    _triggerTrailingFade();
  }

  /// Whether the currently streaming text ends inside a block LaTeX expression.
  bool get _isInsideBlockLatex {
    final text = _displayedText;
    // Count $$ occurrences — odd means we're inside a block
    int count = 0;
    int idx = 0;
    while ((idx = text.indexOf('\$\$', idx)) != -1) {
      count++;
      idx += 2;
    }
    return count.isOdd;
  }

  final StringBuffer _displayedTextBuffer = StringBuffer();

  String get _displayedText => _displayedTextBuffer.toString();

  /// v1.9.1 slice 2: everything received from [stream] so far. In stream mode
  /// the listener only appends here; a single drain timer moves units from
  /// this buffer into [_displayedTextBuffer] per [typingSpeed], so streamed
  /// chunks animate instead of rendering instantly.
  final StringBuffer _receivedTextBuffer = StringBuffer();

  String get _receivedText => _receivedTextBuffer.toString();

  /// v1.9.1 slice 2: set true once the stream emits `onDone`. Completion only
  /// fires when this is true AND the drain has caught up (displayed ==
  /// received).
  bool _streamDone = false;

  /// v1.9.1 slice 3: re-entrancy guard for [_handleControllerChange]'s
  /// stream-mode skip-to-end branch — see the comment at its call site.
  bool _handlingStreamSkipToEnd = false;

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

  // Tracks the exact word-by-word unit index typed so far. Pause cancels the
  // typing Timer, which loses its local `unitIndex` closure variable; resume
  // used to reconstruct that index by replaying the buffer-writing rules
  // (spacing, header newlines) against `_displayedText.length`, and any
  // mismatch between that guess and the real writer logic in
  // `_startWordByWordTypingFromIndex` caused resume to re-type the last
  // word for one frame. Persisting the real index here removes the guess.
  int _wordByWordUnitIndex = 0;
  final Map<String, Widget> _completeMarkdownCache =
      {}; // Only complete markdown states

  // v1.3.3: Internal timer tracking for leak prevention (backward compatible)
  final List<Timer> _allActiveTimers = [];

  // v1.3.3: Compiled regex for performance (backward compatible)
  static final RegExp _arabicBreakPointRegex =
      RegExp(r'[\s\u0600-\u060C\u060E-\u061A\u061C-\u061E\u0621\u0640]');

  /// v1.3.3: Safe setState wrapper to prevent crashes during disposal.
  /// This is an internal method that maintains exact same behavior as setState
  /// but adds safety checks to prevent crashes when widget is disposed during
  /// animation. This change is invisible to external code.
  void _safeSetState(VoidCallback fn) {
    // Quick mounted check
    if (!mounted) return;

    // Attempt setState with safety net for race conditions
    try {
      setState(fn);
    } catch (e) {
      // Only catch disposal errors - these are safe to ignore
      // Re-throw any other errors to maintain debugging capability
      if (e is FlutterError && e.toString().contains('disposed')) {
        // Widget was disposed between mounted check and setState
        // This is expected in fast navigation scenarios - safe to ignore
        return;
      }
      // Unexpected error - rethrow for debugging
      rethrow;
    }
  }

  /// v1.3.3: Create and track a new timer, canceling all previous timers.
  /// This prevents timer leaks when animations are rapidly restarted.
  /// Maintains exact same animation behavior, just safer cleanup.
  void _createTrackedTimer(Timer timer) {
    _cancelAllTrackedTimers();
    _allActiveTimers.add(timer);
    _typeTimer = timer;
  }

  /// v1.3.3: Cancel all tracked timers to prevent leaks.
  /// Internal method - maintains backward compatibility.
  void _cancelAllTrackedTimers() {
    for (final timer in _allActiveTimers) {
      if (timer.isActive) {
        timer.cancel();
      }
    }
    _allActiveTimers.clear();
  }

  @override
  void initState() {
    super.initState();
    _initCursorAnimation();
    _displayedTextBuffer.clear();
    _receivedTextBuffer.clear();
    _streamDone = false;

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

    // v1.9.1 slice 4: a stream identity swap (including stream<->null in
    // either direction) is its own trigger, evaluated BEFORE
    // `_hasConfigurationChanged`/the generic text-diff branches below. Those
    // branches assume `widget.text` holds the content to animate, which is
    // wrong for a stream swap (there is no text to jump to) and would either
    // no-op (old subscription silently kept forever, the bug this fixes) or
    // corrupt state via `_restartAnimation`'s text-based reset. Handle the
    // swap fully here and return, so nothing below re-runs for this case.
    if (!identical(widget.stream, oldWidget.stream)) {
      _handleStreamSwap();
      return;
    }

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

  /// v1.9.1 slice 4: handles `widget.stream` changing identity across a
  /// rebuild — covers stream-A -> stream-B, stream -> null, and null ->
  /// stream. Cancels whatever the OLD configuration was driving (subscription
  /// and/or drain timer), resets all stream/animation state, then re-runs
  /// [_initializeText] so the new configuration (stream or static text)
  /// starts fresh. Without this, a swapped stream instance was silently
  /// ignored — the old subscription kept running (or nothing was subscribed
  /// at all) and the new stream's data was never shown.
  void _handleStreamSwap() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _cancelAllTrackedTimers();
    _typeTimer?.cancel();
    _typeTimer = null;
    _streamDone = false;
    _handlingStreamSkipToEnd = false;

    _safeSetState(() {
      _displayedTextBuffer.clear();
      _receivedTextBuffer.clear();
      _isComplete = false;
      _isError = false;
      _errorMessage = null;
      _isAnimationActive = false;
      _completeMarkdownCache.clear();
      _cleanupAnimations();
    });

    widget.controller?.updateState(StreamingTextState.idle);
    _initializeText();
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
    // v1.3.3: Use safe setState to prevent crashes during disposal
    _safeSetState(() {
      _displayedTextBuffer.clear();
      _displayedTextBuffer.write(widget.text);
      _isComplete = true;
      _isAnimationActive = false;
    });
    widget.controller?.markCompleted();
    _handleCompletion();
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
    // v1.3.3: Use safe setState
    _safeSetState(() {
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
      // v1.3.3: Use safe setState
      _safeSetState(() {
        _isComplete = true;
        _isAnimationActive = false;
      });
      widget.controller?.markCompleted();
      _handleCompletion();
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
    // v1.3.3: Create tracked timer to prevent leaks
    final newTimer = Timer.periodic(widget.typingSpeed, (timer) {
      if (!mounted || index >= appendedUnits.length) {
        timer.cancel();
        // v1.3.3: Use safe setState
        _safeSetState(() {
          _isComplete = true;
          _isAnimationActive = false;
        });
        widget.controller?.markCompleted();
        _handleCompletion();
        return;
      }

      // v1.3.3: Use safe setState
      _safeSetState(() {
        _displayedTextBuffer.write(appendedUnits[index]);
        index++;
        _updateProgress();
      });
    });
    _createTrackedTimer(newTimer);
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

    // v1.9.1 slice 2/3: in stream mode the drain timer owns the display and
    // `widget.text` is '' — the text-based pause/resume/restart paths below
    // all assume `widget.text` holds the content, so running them here would
    // wipe or corrupt the streamed display (e.g. `_restartAnimation` clears
    // the buffer and writes ''). The controller still reflects stream
    // progress for observation. `_skipToEnd()` is the one path that IS
    // stream-safe (slice 3 made it catch up from `_receivedTextBuffer`
    // instead of writing `widget.text`), so skip-to-end is allowed through
    // below; everything else bails out early for stream mode.
    if (widget.stream != null) {
      // Guarded by `_handlingStreamSkipToEnd`: `_skipToEnd()` catches the
      // display up via `_updateProgress()`, which calls
      // `controller.updateProgress()` and synchronously re-enters this
      // listener through `notifyListeners()` — without the guard,
      // `controller.state` is still `completed` and `_isComplete` is still
      // false at that point (it's only set afterwards), causing infinite
      // recursion.
      if (controller.state == StreamingTextState.completed &&
          !_isComplete &&
          !_handlingStreamSkipToEnd) {
        _handlingStreamSkipToEnd = true;
        try {
          _skipToEnd();
        } finally {
          _handlingStreamSkipToEnd = false;
        }
      }
      return;
    }

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
    _cancelAllTrackedTimers(); // v1.3.3: Use tracked timer cleanup
    _typeTimer?.cancel();
    // v1.3.3: Use safe setState
    _streamDone = false;
    _safeSetState(() {
      _displayedTextBuffer.clear();
      _receivedTextBuffer.clear();
      _isComplete = false;
      _isAnimationActive = true;
      _completeMarkdownCache.clear(); // Clear cache on restart
      _cleanupAnimations();
    });
    _initializeText();
  }

  void _skipToEnd() {
    _cancelAllTrackedTimers(); // v1.3.3: Use tracked timer cleanup
    _typeTimer?.cancel();

    if (widget.stream != null) {
      // v1.9.1 slice 3: in stream mode there is no `widget.text` to jump to —
      // only catch the displayed buffer up to what's been received so far.
      // Only actually complete if the stream has already emitted `onDone`;
      // otherwise more chunks may still arrive and completion is premature.
      _safeSetState(() {
        _catchUpDisplayedToReceived();
      });
      if (_streamDone) {
        _completeStream();
      }
      return;
    }

    // v1.3.3: Use safe setState
    _safeSetState(() {
      _displayedTextBuffer.clear();
      _displayedTextBuffer.write(widget.text);
      _isComplete = true;
      _isAnimationActive = false;
    });
    widget.controller?.markCompleted();
    _handleCompletion();
    // Force rebuild to process complete markdown
    // v1.3.3: Use safe setState in callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _safeSetState(() {});
    });
  }

  /// v1.9.1 slice 3: writes everything received so far into the displayed
  /// buffer and cancels any pending drain timer. Used by tap-to-complete and
  /// [_skipToEnd] in stream mode so mid-stream taps/skips catch the display up
  /// to what's arrived instead of erasing it (there is no `widget.text` to
  /// fall back to while streaming). Must be called inside a `_safeSetState`.
  /// Does NOT mark completion — callers decide that based on [_streamDone].
  void _catchUpDisplayedToReceived() {
    _cancelAllTrackedTimers();
    _displayedTextBuffer.clear();
    _displayedTextBuffer.write(_receivedText);
    _updateProgress();
  }

  void _initCursorAnimation() {
    // v1.9.1: `_cursorController` is created for API/back-compat (disposed
    // below) but is intentionally never started and never consumed by
    // build() — no cursor is rendered here. Starting `repeat()` created a
    // ticker that ran for the widget's entire lifetime even though nothing
    // ever read the animation, draining battery and blocking
    // `tester.pumpAndSettle()` in tests. Do not re-add `.repeat()` here
    // without also wiring an actual cursor glyph into build().
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
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

    // Resume from the unit index the typing timer actually reached, not a
    // reconstruction from `_displayedText.length` — recomputing "how many
    // words fit in N characters" has to independently replay the exact
    // spacing/header-newline rules `_startWordByWordTypingFromIndex` uses to
    // write the buffer, and any drift between the two duplicates or skips a
    // word on resume (see `_wordByWordUnitIndex` doc comment).
    final currentUnitIndex = _wordByWordUnitIndex.clamp(0, units.length);

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

    final currentIndex = _displayedText.characters.length;
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

    final currentIndex = _displayedText.characters.length;

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
    if (widget.controller != null) {
      if (widget.stream != null) {
        // v1.9.1 slice 2: in stream mode `widget.text` is '' — progress is
        // measured against what the stream has delivered so far. It may
        // regress when a new chunk arrives (received grows), which is
        // acceptable. Always cap strictly below 1.0 here: reaching exactly 1.0
        // via `updateProgress` would auto-fire the controller's completion
        // callback, and `_completeStream` also fires it via `markCompleted`,
        // which would double-fire. Completion (and the exact 1.0 progress) is
        // single-sourced through `markCompleted()` at real stream completion.
        final received = _receivedText.length;
        if (received > 0) {
          final progress = (_displayedText.length / received).clamp(0.0, 0.999);
          widget.controller!.updateProgress(progress);
        }
      } else if (widget.text.isNotEmpty) {
        final progress = _displayedText.length / widget.text.length;
        widget.controller!.updateProgress(progress);
      }
    }
    // Trigger trailing-edge fade for markdown content
    _triggerTrailingFade();
    // v1.9.1 slice 5: notify listeners (e.g. StreamingTextMarkdown's
    // auto-scroll) that the displayed buffer grew. `_updateProgress` is
    // already called from every buffer-write call site across typing,
    // draining, and catch-up, so this is the single natural hook — no new
    // write sites needed.
    widget.onTextChanged?.call();
  }

  void _handleStream() {
    _streamSubscription?.cancel();

    // v1.3.3: Check if stream is already broadcast to prevent double-wrapping
    final stream = widget.stream!;
    final effectiveStream =
        stream.isBroadcast ? stream : stream.asBroadcastStream();

    // v1.9.1 slice 2: the listener does the MINIMUM — append the chunk to
    // `_receivedTextBuffer` and make sure a drain timer is running. It never
    // touches `_displayedTextBuffer`; the drain timer reveals received text
    // incrementally per `typingSpeed`/`chunkSize`/`wordByWord` so streamed
    // chunks animate like typed text instead of appearing instantly.
    _streamSubscription = effectiveStream.listen(
      (data) {
        // Guard against callbacks arriving after the element is unmounted — a
        // broadcast stream can still deliver a buffered event during teardown,
        // and touching state / the binding then trips `!inTest`.
        if (!mounted) return;
        _safeSetState(() {
          _receivedTextBuffer.write(data);
          _isError = false;
          _errorMessage = null;
          _isAnimationActive = true;
        });
        _ensureStreamDrain();
      },
      onError: (error) {
        if (!mounted) return;
        // v1.3.3: Use safe setState
        _safeSetState(() {
          _isError = true;
          _errorMessage = error.toString();
        });
      },
      onDone: () {
        if (!mounted) return;
        _streamDone = true;
        // If the drain has already caught up (displayed == received) there is
        // no pending timer to finish it, so complete here. Otherwise the
        // running drain timer will detect `_streamDone` when it catches up and
        // complete then — completion waits for the drain to finish.
        if (_displayedText.length >= _receivedText.length) {
          _completeStream();
        } else {
          _ensureStreamDrain();
        }
      },
    );
  }

  /// v1.9.1 slice 2: ensure exactly one drain timer is running. The
  /// single-timer invariant is held via [_createTrackedTimer] /
  /// [_cancelAllTrackedTimers]. When the drain catches up before the stream is
  /// done it cancels itself; the next arriving chunk (or `onDone`) restarts it
  /// through this method.
  void _ensureStreamDrain() {
    if (!mounted || _isComplete) return;
    // Already draining — nothing to do (avoid stacking timers).
    if (_typeTimer?.isActive == true) return;
    // Nothing left to reveal right now.
    if (_displayedText.length >= _receivedText.length) {
      if (_streamDone) _completeStream();
      return;
    }

    // typingSpeed == Duration.zero (e.g. the .instant preset): drain the whole
    // buffer immediately rather than scheduling a zero-delay timer per unit.
    if (widget.typingSpeed == Duration.zero) {
      _safeSetState(() {
        _drainStep(revealAll: true);
      });
      if (_streamDone && _displayedText.length >= _receivedText.length) {
        _completeStream();
      }
      return;
    }

    final timer = Timer.periodic(widget.typingSpeed, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      // Caught up to what's been received so far.
      if (_displayedText.length >= _receivedText.length) {
        timer.cancel();
        if (_streamDone) {
          _completeStream();
        }
        // else: idle until the next chunk restarts the drain via
        // `_ensureStreamDrain` — preserves the single-timer invariant.
        return;
      }

      var madeProgress = false;
      _safeSetState(() {
        madeProgress = _drainStep(revealAll: false);
      });

      // After revealing, if we've caught up and the stream is done, finish.
      if (_streamDone && _displayedText.length >= _receivedText.length) {
        timer.cancel();
        _completeStream();
        return;
      }

      // No progress this tick means we're holding back a trailing partial word
      // (word mode, whitespace not yet arrived, stream not done). Stop spinning
      // — the next chunk or `onDone` restarts the drain via `_ensureStreamDrain`.
      if (!madeProgress) {
        timer.cancel();
      }
    });
    _createTrackedTimer(timer);
  }

  /// v1.9.1 slice 2: move one unit (or all, when [revealAll]) from received to
  /// displayed. Must be called inside a `_safeSetState`. Char mode takes
  /// `chunkSize` graphemes via [Characters] (never splits an emoji); word mode
  /// takes the next whole word and holds back a trailing partial word until
  /// whitespace arrives or the stream is done (so a half word never renders
  /// mid-stream). Whitespace is preserved exactly so displayed byte-matches
  /// received at completion.
  /// Returns `true` if it revealed at least one unit, `false` if it made no
  /// progress (word mode holding back a trailing partial word). Callers use the
  /// `false` result to stop the drain timer until more data arrives.
  bool _drainStep({required bool revealAll}) {
    final received = _receivedText;
    final displayedLen = _displayedText.length;
    if (displayedLen >= received.length) return false;

    final remainder = received.substring(displayedLen);

    if (revealAll) {
      _displayedTextBuffer.write(remainder);
      _updateProgress();
      return true;
    }

    if (widget.wordByWord) {
      // Find the next whitespace boundary in the remaining received text.
      final wsIndex = remainder.indexOf(RegExp(r'\s'));
      if (wsIndex == -1) {
        // No whitespace yet — this is a (possibly partial) trailing word.
        // Only reveal it once the stream is done; otherwise hold it back so a
        // half word never shows.
        if (_streamDone) {
          _displayedTextBuffer.write(remainder);
          _updateProgress();
          return true;
        }
        return false;
      }
      // Reveal the word plus its single following whitespace char so spacing
      // is reconstructed exactly (byte-for-byte with received).
      final chunk = remainder.substring(0, wsIndex + 1);
      _displayedTextBuffer.write(chunk);
      _updateProgress();
      return true;
    }

    // Character mode: reveal up to `chunkSize` graphemes, grapheme-safe.
    final take = widget.chunkSize < 1 ? 1 : widget.chunkSize;
    final chunk = remainder.characters.take(take).toString();
    _displayedTextBuffer.write(chunk);
    _updateProgress();
    return true;
  }

  /// v1.9.1 slice 2: single, idempotent stream-completion path. Fires only on
  /// the `!_isComplete → _isComplete` transition, so `onComplete` /
  /// `controller.markCompleted()` fire EXACTLY ONCE. The trailing-fade
  /// dismissal rides on the same `_handleCompletion()` call.
  void _completeStream() {
    if (_isComplete) return;
    _cancelAllTrackedTimers();
    // The stream has emitted `onDone` and the drain has caught up — nothing
    // more will ever arrive. Cancel the (broadcast) subscription so no timer or
    // stream callback survives past completion. Without this the subscription
    // stays live until `dispose()`, which under a widget-test `FakeAsync` (where
    // the source controller is closed via `addTearDown`) leaves a dangling
    // listener that hangs test finalization.
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _safeSetState(() {
      _isComplete = true;
      _isAnimationActive = false;
    });
    widget.controller?.markCompleted();
    _handleCompletion();
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
    _wordByWordUnitIndex = 0;
    _displayedTextBuffer.clear();

    // v1.3.3: Create tracked timer to prevent leaks
    _cancelAllTrackedTimers();
    final newTimer = Timer.periodic(widget.typingSpeed, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (unitIndex >= units.length) {
        timer.cancel();
        // v1.3.3: Use safe setState
        _safeSetState(() {
          _isComplete = true;
          _isAnimationActive = false; // Animation is now complete
        });
        widget.controller?.markCompleted();
        _handleCompletion();
        // Force rebuild to process complete markdown
        // v1.3.3: Use safe setState in callback
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _safeSetState(() {});
        });
        return;
      }

      // v1.3.3: Use safe setState
      _safeSetState(() {
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
        _wordByWordUnitIndex = endIndex;
        _updateProgress();
      });
    });
    _createTrackedTimer(newTimer);
  }

  void _startWordByWordTypingFromIndex(List<String> units, int startIndex) {
    int unitIndex = startIndex;
    _wordByWordUnitIndex = startIndex;

    // v1.3.3: Create tracked timer
    _cancelAllTrackedTimers();
    final newTimer = Timer.periodic(widget.typingSpeed, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (unitIndex >= units.length) {
        timer.cancel();
        // v1.3.3: Use safe setState
        _safeSetState(() {
          _isComplete = true;
          _isAnimationActive = false;
        });
        widget.controller?.markCompleted();
        _handleCompletion();
        // v1.3.3: Use safe setState in callback
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _safeSetState(() {});
        });
        return;
      }

      // v1.3.3: Use safe setState
      _safeSetState(() {
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
        _wordByWordUnitIndex = endIndex;
        _updateProgress();
      });
    });
    _createTrackedTimer(newTimer);
  }

  void _startCharacterByCharacterTypingFromIndexWithContinuation(
      List<String> oldTextUnits, int startIndex, String appendedText) {
    int index = startIndex;

    // v1.3.3: Create tracked timer
    _cancelAllTrackedTimers();
    final newTimer = Timer.periodic(widget.typingSpeed, (timer) {
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

      // v1.3.3: Use safe setState
      _safeSetState(() {
        for (int i = 0; i < currentChunkSize; i++) {
          if (index < oldTextUnits.length) {
            _displayedTextBuffer.write(oldTextUnits[index]);
            index++;
            _updateProgress();
          }
        }
      });
    });
    _createTrackedTimer(newTimer);
  }

  void _startCharacterByCharacterTypingFromIndex(
      List<String> units, int startIndex) {
    int index = startIndex;

    // v1.3.3: Create tracked timer
    _cancelAllTrackedTimers();
    final newTimer = Timer.periodic(widget.typingSpeed, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (index >= units.length) {
        timer.cancel();
        // v1.3.3: Use safe setState
        _safeSetState(() {
          _isComplete = true;
          _isAnimationActive = false;
        });
        widget.controller?.markCompleted();
        _handleCompletion();
        // v1.3.3: Use safe setState in callback
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _safeSetState(() {});
        });
        return;
      }

      final chunkSize = widget.chunkSize;
      final remainingUnits = units.length - index;
      final currentChunkSize =
          chunkSize > remainingUnits ? remainingUnits : chunkSize;

      // v1.3.3: Use safe setState
      _safeSetState(() {
        final chunk = units.getRange(index, index + currentChunkSize).join();
        _displayedTextBuffer.write(chunk);
        _updateProgress();
      });

      index += currentChunkSize;
    });
    _createTrackedTimer(newTimer);
  }

  List<String> _splitArabicWords(String text) {
    // Use the same markdown-aware splitting as LTR text.
    // Arabic words are separated by whitespace — do NOT strip Arabic
    // punctuation or letters (hamza, tatweel, etc.) as delimiters.
    final words = <String>[];
    final lines = text.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.startsWith('### ') ||
          line.startsWith('## ') ||
          line.startsWith('# ')) {
        words.add(line);
      } else if (line.trim().startsWith('> ')) {
        words.add(line);
      } else if (line.trim().startsWith('- ') ||
          line.trim().startsWith('* ') ||
          RegExp(r'^\d+\.\s').hasMatch(line.trim())) {
        words.add(line);
      } else if (line.trim().isEmpty) {
        words.add(line);
      } else {
        final lineWords = line.split(RegExp(r'\s+'));
        words.addAll(lineWords.where((w) => w.isNotEmpty));
      }

      if (i < lines.length - 1) {
        words.add('\n');
      }
    }

    return words;
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

    // v1.3.3: Create tracked timer
    _cancelAllTrackedTimers();
    final newTimer = Timer.periodic(widget.typingSpeed, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (index >= units.length) {
        timer.cancel();
        // v1.3.3: Use safe setState
        _safeSetState(() {
          _isComplete = true;
          _isAnimationActive = false; // Animation is now complete
        });
        widget.controller?.markCompleted();
        _handleCompletion();
        // Force rebuild to process complete markdown
        // v1.3.3: Use safe setState in callback
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _safeSetState(() {});
        });
        return;
      }

      final chunkSize = widget.chunkSize;
      final remainingUnits = units.length - index;
      final currentChunkSize =
          chunkSize > remainingUnits ? remainingUnits : chunkSize;

      // v1.3.3: Use safe setState
      _safeSetState(() {
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
    _createTrackedTimer(newTimer);
  }

  void _startRTLCharacterTyping() {
    final groups = _getArabicGroups(widget.text);
    int groupIndex = 0;

    _displayedTextBuffer.clear();

    // v1.3.3: Create tracked timer
    _cancelAllTrackedTimers();
    final newTimer = Timer.periodic(widget.typingSpeed, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (groupIndex >= groups.length) {
        timer.cancel();
        // v1.3.3: Use safe setState
        _safeSetState(() {
          _isComplete = true;
          _isAnimationActive = false;
        });
        _handleCompletion();
        // Force rebuild to process complete markdown
        // v1.3.3: Use safe setState in callback
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _safeSetState(() {});
        });
        return;
      }

      // v1.3.3: Use safe setState
      _safeSetState(() {
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
    _createTrackedTimer(newTimer);
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

  /// v1.3.3: Optimized using pre-compiled regex (backward compatible)
  bool _isGroupBreakPoint(String current, String next) {
    // v1.3.3: Check each character separately to avoid string concatenation
    // and use compiled regex for performance
    return _arabicBreakPointRegex.hasMatch(current) ||
        _arabicBreakPointRegex.hasMatch(next);
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

  /// v1.3.3: Improved AnimationController cleanup with proper safety checks.
  /// Maintains backward compatibility while preventing disposal crashes.
  void _cleanupAnimations() {
    for (final controller in _characterAnimations.values.toList()) {
      // v1.3.3: Check animation state before disposal
      if (controller.isAnimating) {
        controller.stop();
      }

      // Safe disposal with specific error handling
      try {
        controller.dispose();
      } on FlutterError catch (e) {
        // Only ignore disposal errors - rethrow others for debugging
        if (!e.toString().contains('disposed')) {
          rethrow;
        }
      }
    }
    _characterAnimations.clear();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.completeAnimationOnTap
          ? () {
              if (widget.stream != null) {
                // v1.9.1 slice 3: mid-stream, there is no `widget.text` to
                // jump to — catch the display up to what's been received and
                // only complete if the stream has already finished. Erasing
                // to '' (the old behavior, driven by `widget.text`) would
                // wipe out everything the user has streamed in so far.
                _cancelAllTrackedTimers();
                _safeSetState(() {
                  _catchUpDisplayedToReceived();
                });
                if (_streamDone) {
                  _completeStream();
                }
                return;
              }

              _typeTimer?.cancel();
              _safeSetState(() {
                _displayedTextBuffer.clear();
                _displayedTextBuffer.write(widget.text);
                _isComplete = true;
                _isAnimationActive = false;
              });
              _handleCompletion();
              // Force rebuild to process complete markdown
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _safeSetState(() {});
              });
            }
          : null,
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
      Widget markdownContent = Container(
        width: double.infinity,
        alignment: effectiveAlignment == TextAlign.right
            ? Alignment.centerRight
            : (effectiveAlignment == TextAlign.center
                ? Alignment.center
                : Alignment.centerLeft),
        child: _buildMarkdownBody(),
      );

      // Apply trailing-edge fade when streaming with markdown
      if (_markdownFadeAllowed) {
        if (_isInsideBlockLatex) {
          // Inside a block LaTeX: use whole-widget opacity pulse
          markdownContent = AnimatedBuilder(
            animation: _groupAnimationController,
            builder: (context, child) {
              final value = widget.fadeInCurve.transform(
                _groupAnimationController.value.clamp(0.0, 1.0),
              );
              // Pulse between 0.7 and 1.0 to avoid full disappearance
              return Opacity(
                opacity: 0.7 + (0.3 * value),
                child: child,
              );
            },
            child: markdownContent,
          );
        } else {
          // Normal markdown: trailing-edge gradient fade
          markdownContent = AnimatedBuilder(
            animation: _groupAnimationController,
            builder: (context, child) {
              final value = widget.fadeInCurve.transform(
                _groupAnimationController.value.clamp(0.0, 1.0),
              );
              // When animation is complete (1.0), show fully opaque
              // When animation starts (0.0), fade the bottom edge
              return ShaderMask(
                shaderCallback: (Rect bounds) {
                  if (bounds.height <= 0) {
                    // Safety: no content to fade
                    return const LinearGradient(
                      colors: [Colors.white, Colors.white],
                    ).createShader(bounds);
                  }
                  // Fade the bottom 40px of the content
                  final fadeHeight = 40.0 * (1.0 - value);
                  final fadeStart =
                      (bounds.height - fadeHeight).clamp(0.0, bounds.height);
                  final stop = (fadeStart / bounds.height).clamp(0.0, 0.999);
                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: const [
                      Colors.white,
                      Colors.white,
                      Colors.transparent
                    ],
                    stops: [0.0, stop, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: child,
              );
            },
            child: markdownContent,
          );
        }
      }

      return Directionality(
        textDirection: effectiveTextDirection,
        child: markdownContent,
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

    // Trailing-edge fade for non-markdown content (including RTL/Arabic)
    if (widget.animationsEnabled &&
        widget.fadeInEnabled &&
        !widget.markdownEnabled &&
        !_isComplete) {
      Widget plainContent = Text(
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
      return AnimatedBuilder(
        animation: _groupAnimationController,
        builder: (context, child) {
          final value = widget.fadeInCurve.transform(
            _groupAnimationController.value.clamp(0.0, 1.0),
          );
          return ShaderMask(
            shaderCallback: (Rect bounds) {
              if (bounds.height <= 0) {
                return const LinearGradient(
                  colors: [Colors.white, Colors.white],
                ).createShader(bounds);
              }
              final fadeHeight = 40.0 * (1.0 - value);
              final fadeStart =
                  (bounds.height - fadeHeight).clamp(0.0, bounds.height);
              final stop = (fadeStart / bounds.height).clamp(0.0, 0.999);
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [Colors.white, Colors.white, Colors.transparent],
                stops: [0.0, stop, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: child,
          );
        },
        child: plainContent,
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

    // If no controller, fade-in is disallowed, or typing has finished,
    // render static fully-opaque text. Once `_isComplete`, no character may
    // still be stuck below full opacity waiting on its own AnimationController:
    // under real frame-timing jitter (a slow/throttled tab, an animation
    // controller re-keyed to a different index mid-run) a chunk's controller
    // can settle a fraction below 1.0, which otherwise reads as a randomly
    // missing glyph (reported for the em-dash under the bouncy preset,
    // reproducing intermittently — never on a deterministic test clock).
    // Forcing a static render at completion guarantees every character ends
    // up fully visible regardless of what its controller did along the way.
    if (controller == null || !_fadeInAllowed || _isComplete) {
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
          final curveValue =
              widget.fadeInCurve.transform(controller.value).clamp(0.0, 1.0);

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

    // Real math typesetting via flutter_math_fork (fractions, superscripts,
    // radicals, etc. rendered as actual glyph layout, not fused plain text).
    // Safe against partial/incomplete expressions: the streaming/character
    // parsers only ever classify a segment as LaTeX once its closing
    // delimiter has been fully typed (see _parseTextUnitsWithLatex /
    // _parseCharacterUnitsWithLatex), so Math.tex here never sees a
    // half-typed expression. A malformed expression still can't crash the
    // widget tree: Math.tex catches parse/build errors internally and
    // falls back to onErrorFallback below.
    final children = <Widget>[];
    final defaultColor =
        widget.latexStyle?.color ?? widget.style?.color ?? Colors.blue;
    final latexFontSize =
        (widget.latexStyle?.fontSize ?? widget.style?.fontSize ?? 16) *
            widget.latexScale;

    for (final segment in segments) {
      if (segment.isLaTeX) {
        // Render LaTeX content as real typeset math
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
            child: Math.tex(
              segment.content,
              mathStyle: segment.type == SegmentType.blockLaTeX
                  ? MathStyle.display
                  : MathStyle.text,
              textStyle: TextStyle(
                fontSize: latexFontSize,
                color: defaultColor,
                fontWeight: FontWeight.w500,
              ),
              onErrorFallback: (error) => SelectableText(
                segment.fullExpression,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: latexFontSize,
                  color: defaultColor,
                ),
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

  /// Withholds a trailing INCOMPLETE ``` code fence from the markdown
  /// *render* while it's still being typed. [_displayedText] itself (typing
  /// position, progress, resume-from-index, cache key, etc.) is untouched —
  /// this only affects what gets handed to `GptMarkdown` for display.
  ///
  /// Without this, an in-progress fence's raw backtick characters render as
  /// literal unstyled text while they're being typed. The instant the
  /// closing ``` completes, gpt_markdown recognizes the block and
  /// reformats it as a styled code block, which strips those fence
  /// markers from the visible output — the rendered text visibly shrinks
  /// by a few characters at that exact moment, reading as a stutter on
  /// top of the typing animation. Holding the render at the last point
  /// before an open fence (and releasing the whole block only once it's
  /// balanced) means the block only ever appears in its final, styled
  /// form, growing normally.
  String _stableRenderText(String text) {
    final fenceCount = '```'.allMatches(text).length;
    if (fenceCount.isEven) return text;
    return text.substring(0, text.lastIndexOf('```'));
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

    // Use gpt_markdown's GptMarkdown widget
    final markdownWidget = GptMarkdown(
      _stableRenderText(currentText),
      style: widget.markdownStyleSheet,
      textDirection: widget.textDirection ?? TextDirection.ltr,
      textAlign: widget.textAlign,
      textScaler: widget.textScaler,
      imageBuilder: widget.imageBuilder == null
          ? null
          : (ctx, url, width, height) => widget.imageBuilder!(ctx, url),
      onLinkTap: widget.onLinkTap,
      codeBuilder: widget.codeBuilder,
      latexBuilder: widget.latexBuilder,
      sourceTagBuilder: widget.sourceTagBuilder,
      inlineCodeBuilder: widget.highlightBuilder == null
          ? null
          : (context, code, style, codeStyle) => baselineWidgetSpan(
                widget.highlightBuilder!(context, code, style),
              ),
      linkBuilder: widget.linkBuilder,
      components: widget.components,
      inlineComponents: widget.inlineComponents,
    );

    // Cache only complete, final states
    if (!_isAnimationActive && _isComplete) {
      _completeMarkdownCache[currentText] = markdownWidget;
    }

    return markdownWidget;
  }

  /// Helper method to render formatted text for LaTeX segments
  /// Kept for LaTeX mixed content rendering
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

  @override
  void dispose() {
    // v1.3.3: Use safe timer cleanup to prevent leaks
    _cancelAllTrackedTimers();
    _typeTimer?.cancel(); // Fallback for any untracked timers

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
