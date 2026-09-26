import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:gpt_markdown/gpt_markdown.dart' hide RevealEngine;

import '../controller/streaming_text_controller.dart';
import '../engine/atomic_spans.dart';
import '../engine/reveal_engine.dart';
import '../engine/reveal_scheduler.dart';
import '../engine/unit_policy.dart';
import '../render/caret_inline.dart';
import '../render/fade_span.dart';
import '../render/markdown_options.dart';
import '../render/markdown_renderer.dart';
import '../render/streaming_caret.dart';
import '../theme/streaming_tokens.dart';

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
///
/// Internally, the reveal is driven by a pure-Dart [RevealEngine] +
/// [RevealScheduler] pair (see `lib/src/engine/`): the engine is the single
/// source of truth for "how much of the source has been revealed", so the
/// rendered text is always a literal prefix of the source, and completion
/// ([onComplete] / [StreamingTextController.onCompleted]) fires from exactly
/// one place, exactly once per revealing-to-complete transition.
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
    this.markdownOptions,
    this.completeAnimationOnTap = true,
    this.onTextChanged,
    this.errorBuilder,
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
  /// revealed, in plain-text mode only (markdown mode never per-glyph
  /// fades). A single [Ticker] drives every fading run; suppressed while the
  /// displayed text contains Arabic.
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
  /// Defaults to `false`.
  final bool trailingFadeEnabled;

  /// Custom builder for images in markdown content.
  final Widget Function(BuildContext context, String imageUrl)? imageBuilder;

  /// Callback when a link is tapped in markdown content.
  final void Function(String url, String title)? onLinkTap;

  /// Custom builder for code blocks in markdown content.
  final Widget Function(
    BuildContext context,
    String name,
    String code,
    bool closed,
  )?
  codeBuilder;

  /// Custom builder for LaTeX expressions in markdown content.
  final Widget Function(
    BuildContext context,
    String tex,
    TextStyle textStyle,
    bool inline,
  )?
  latexBuilder;

  /// Custom builder for source tags in markdown content.
  final Widget Function(
    BuildContext context,
    String content,
    TextStyle textStyle,
  )?
  sourceTagBuilder;

  /// Custom builder for highlighted text in markdown content.
  final Widget Function(BuildContext context, String text, TextStyle style)?
  highlightBuilder;

  /// Custom builder for links in markdown content.
  final Widget Function(
    BuildContext context,
    InlineSpan text,
    String url,
    TextStyle style,
  )?
  linkBuilder;

  /// Custom block-level markdown components. Forwarded as-is to
  /// `gpt_markdown`'s `GptMarkdown.components`. Use this to override how
  /// headers, lists, bold, italic, tables, etc. are rendered. When `null`,
  /// `gpt_markdown`'s default component list is used.
  @Deprecated(
    'Use markdownOptions.blockComponents. Passing components at all (even '
    'an empty list) switches gpt_markdown onto its legacy regex pipeline, '
    'which has no incremental segment cache. Will be removed in 2.0.0.',
  )
  final List<MarkdownComponent>? components;

  /// Custom inline markdown components. Forwarded as-is to
  /// `gpt_markdown`'s `GptMarkdown.inlineComponents`. When `null`,
  /// `gpt_markdown`'s default inline component list is used.
  @Deprecated(
    'Use markdownOptions.inlinePatterns. Passing inlineComponents at all '
    '(even an empty list) switches gpt_markdown onto its legacy regex '
    'pipeline, which has no incremental segment cache. '
    'Will be removed in 2.0.0.',
  )
  final List<MarkdownComponent>? inlineComponents;

  /// Bundles `gpt_markdown` 1.3 pass-throughs that don't have a dedicated
  /// top-level parameter of their own (style sheet, block/inline builders,
  /// autolink config, ...). See [MarkdownRenderOptions].
  final MarkdownRenderOptions? markdownOptions;

  /// Whether tapping the widget jumps the animation to completion.
  ///
  /// Defaults to `true`. Set to `false` to let the animation play through
  /// uninterrupted regardless of taps.
  final bool completeAnimationOnTap;

  /// Internal hook fired whenever the revealed text grows during
  /// animation/streaming. Not part of the public [StreamingTextMarkdown] API
  /// surface directly — used internally to drive auto-scroll pinning while
  /// content grows, rather than only once at completion.
  final VoidCallback? onTextChanged;

  /// Builder invoked when [stream] emits an error. Receives the error
  /// object; the text revealed so far stays on screen either way.
  ///
  /// When `null`, a default view is shown: the text revealed so far, plus a
  /// trailing `Error: $error` line in `Theme.of(context).colorScheme.error`.
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  @override
  State<StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<StreamingText>
    with TickerProviderStateMixin {
  late RevealEngine _engine;
  late RevealScheduler _scheduler;

  StreamSubscription<String>? _streamSubscription;

  bool _isComplete = false;
  Object? _error;

  /// Mirrors `MediaQuery.maybeDisableAnimationsOf(context)`, kept in sync in
  /// [didChangeDependencies]. Reduced motion behaves like
  /// `animationsEnabled: false`: instant reveal, zero-duration fade, and a
  /// static (non-pulsing) caret.
  bool _reducedMotion = false;

  /// Tracks whether the single completion accessibility announcement has
  /// already fired for the current revealing-to-complete cycle, mirroring
  /// [_isComplete] as observed by [build] - reset the moment [_isComplete]
  /// goes back to `false` (restart).
  bool _announcedCompletion = false;

  /// Re-entrancy guard for [_handleControllerChange]: several branches call
  /// engine/scheduler methods that can synchronously re-notify the
  /// controller (e.g. `markCompleted` -> `notifyListeners`).
  bool _handlingControllerChange = false;

  /// Drives fade-run opacity and per-frame rebuilds while the engine is
  /// revealing or a fade is still settling. Exactly one [Ticker] for the
  /// whole widget (Phase B seam): never one per character.
  Ticker? _ticker;

  /// A monotonic clock shared between [RevealEngine]'s reveal-run
  /// timestamps and this widget's fade rendering, so `now - revealedAt`
  /// stays consistent without needing wall-clock [DateTime] math.
  final Stopwatch _fadeClock = Stopwatch()..start();

  DateTime _engineClock() =>
      DateTime.fromMicrosecondsSinceEpoch(_fadeClock.elapsedMicroseconds);

  Duration _now() => Duration(microseconds: _fadeClock.elapsedMicroseconds);

  /// Kept only for the trailing-edge [ShaderMask] dismiss animation
  /// ([StreamingText.trailingFadeEnabled]) — unrelated to the single-ticker
  /// per-glyph fade, and cheap: one bounded-duration controller, started
  /// once on completion, disposed with the state.
  late AnimationController _groupAnimationController;

  // Incremental "does the revealed text contain Arabic" cache: a static,
  // once-compiled RegExp, scanned only over the NEW suffix since the last
  // check (append-only growth is the common case) instead of re-scanning
  // the whole buffer - or recompiling a RegExp - on every tick (W-perf).
  static final RegExp _arabicRegex = RegExp(
    r'[؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]',
  );
  bool _arabicCached = false;
  int _arabicCheckedLength = 0;

  bool _containsArabic(String text) {
    if (_arabicCached) return true;
    if (text.length > _arabicCheckedLength) {
      if (_arabicRegex.hasMatch(text.substring(_arabicCheckedLength))) {
        _arabicCached = true;
      } else {
        _arabicCheckedLength = text.length;
      }
    } else if (text.length < _arabicCheckedLength) {
      // A non-append change: the cached suffix scan is no longer valid.
      _arabicCheckedLength = 0;
      _arabicCached = false;
      return _containsArabic(text);
    }
    return _arabicCached;
  }

  void _resetArabicCache() {
    _arabicCached = false;
    _arabicCheckedLength = 0;
  }

  UnitPolicy _buildPolicy() {
    if (widget.wordByWord) return const WordPolicy();
    final chunkSize = widget.chunkSize > 0 ? widget.chunkSize : 1;
    return CharPolicy(chunkSize: chunkSize);
  }

  Duration _effectiveInterval() {
    final multiplier = widget.controller?.speedMultiplier ?? 1.0;
    if (multiplier <= 0) return widget.typingSpeed;
    final micros = widget.typingSpeed.inMicroseconds / multiplier;
    if (!micros.isFinite) return Duration.zero;
    return Duration(microseconds: micros.round());
  }

  void _createEngineAndScheduler() {
    _engine = RevealEngine(
      policy: _buildPolicy(),
      atomicSpans: widget.latexEnabled ? const AtomicSpanDetector() : null,
      onComplete: _handleEngineComplete,
      clock: _engineClock,
    );
    _scheduler = RevealScheduler(
      engine: _engine,
      interval: _effectiveInterval(),
    );
  }

  void _syncEngineConfig() {
    _engine.policy = _buildPolicy();
    _engine.atomicSpans = widget.latexEnabled ? const AtomicSpanDetector() : null;
    _scheduler.interval = _effectiveInterval();
  }

  bool get _instantReveal =>
      !widget.animationsEnabled || _effectiveInterval() == Duration.zero;

  void _applyImmediateRevealIfNeeded() {
    if (_instantReveal) {
      _engine.revealAll();
    }
  }

  void _initSource() {
    if (widget.stream != null) {
      _engine.setSource('', closed: false);
      _subscribeStream(widget.stream!);
    } else {
      _engine.setSource(widget.text, closed: true);
    }
    _applyImmediateRevealIfNeeded();
    // Always move off `idle` once a reveal has actually started - including
    // when `animationsEnabled: false` reveals it instantly. Otherwise the
    // controller would stay `idle` forever in that mode, and the "stop()
    // was called" branch in `_handleControllerChange` (keyed on
    // `state == idle`) would misfire on every progress notification and
    // repeatedly reset the engine back to empty.
    if (!_isComplete && _error == null) {
      widget.controller?.updateState(StreamingTextState.animating);
    }
    _scheduler.start();
    _syncTicker();
  }

  void _subscribeStream(Stream<String> stream) {
    _streamSubscription = stream.listen(
      _onStreamData,
      onDone: _onStreamDone,
      onError: _onStreamError,
    );
  }

  void _onStreamData(String chunk) {
    if (!mounted) return;
    setState(() {
      _engine.append(chunk);
      _applyImmediateRevealIfNeeded();
    });
    _scheduler.wake();
    _syncTicker();
    widget.onTextChanged?.call();
  }

  void _onStreamDone() {
    if (!mounted) return;
    setState(() {
      _engine.close();
    });
    _scheduler.wake();
    _syncTicker();
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    if (!mounted) return;
    _scheduler.stop();
    setState(() {
      _error = error;
    });
    widget.controller?.markError(error, stackTrace);
  }

  void _handleEngineComplete() {
    if (!mounted) return;
    setState(() {
      _isComplete = true;
    });
    widget.controller?.markCompleted();
    widget.onComplete?.call();
    if (widget.animationsEnabled && widget.trailingFadeEnabled) {
      _groupAnimationController.forward();
    }
    _syncTicker();
  }

  void _handleStreamSwap() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _scheduler.dispose();
    _resetArabicCache();
    _createEngineAndScheduler();
    setState(() {
      _isComplete = false;
      _error = null;
    });
    widget.controller?.updateState(StreamingTextState.idle);
    _initSource();
  }

  void _handleControllerChange() {
    if (widget.controller == null || !mounted || _handlingControllerChange) {
      return;
    }
    _handlingControllerChange = true;
    try {
      final controller = widget.controller!;
      _syncEngineConfig();

      // pause/resume -> the scheduler. Works in stream mode too (W15).
      if (controller.isPaused && !_scheduler.isPaused) {
        _scheduler.pause();
      } else if (!controller.isPaused &&
          controller.state == StreamingTextState.animating &&
          _scheduler.isPaused) {
        _scheduler.resume();
      }

      // stop -> idle, progress 0: reset the reveal and halt (W15).
      if (controller.state == StreamingTextState.idle) {
        _engine.reset();
        _scheduler.stop();
        if (_isComplete) {
          setState(() {
            _isComplete = false;
          });
        }
      }

      // restart -> animating, progress 0: (re)start the scheduler. Only
      // reset the engine if it had actually made progress (cursor > 0) —
      // after `stop()` the cursor is already 0 (see the idle branch above),
      // and unconditionally starting the scheduler there is exactly what
      // resumes it; re-checking cursor only guards the reset call, not
      // whether we start, so `stop()` followed by `restart()` still works.
      // This also fires harmlessly at the initial mount (cursor already 0,
      // `start()` is idempotent). Works in stream mode too: the accumulated
      // source and `inputClosed` are untouched by reset(), so a restart
      // mid-stream replays everything received so far and keeps accepting
      // new chunks (W15).
      if (controller.state == StreamingTextState.animating &&
          controller.progress == 0.0) {
        if (_engine.cursor > 0) {
          _engine.reset();
        }
        if (_isComplete) {
          setState(() {
            _isComplete = false;
          });
        }
        _scheduler.start();
      }

      // skipToEnd -> revealAll. In stream mode this only actually completes
      // once the stream itself has closed (W3).
      if (controller.state == StreamingTextState.completed && !_isComplete) {
        _engine.revealAll();
      }
    } finally {
      _handlingControllerChange = false;
    }
    _scheduler.wake();
    _syncTicker();
  }

  void _swapController(StreamingTextController? oldController) {
    oldController?.removeListener(_handleControllerChange);
    widget.controller?.addListener(_handleControllerChange);
    final StreamingTextState state;
    if (_error != null) {
      state = StreamingTextState.error;
    } else if (_isComplete) {
      state = StreamingTextState.completed;
    } else if (_scheduler.isPaused) {
      state = StreamingTextState.paused;
    } else {
      state = StreamingTextState.animating;
    }
    widget.controller?.updateState(state);
  }

  void _handleTap() {
    if (!widget.completeAnimationOnTap) return;
    if (_isComplete || _error != null) return; // W3: no-op once complete.
    setState(() {
      _engine.revealAll();
    });
    _scheduler.wake();
    _syncTicker();
  }

  // ---- Fade -----------------------------------------------------------

  bool get _fadeAllowed =>
      widget.animationsEnabled &&
      widget.fadeInEnabled &&
      !widget.markdownEnabled &&
      !_containsArabic(_engine.revealed);

  bool get _trailingFadeAllowed =>
      widget.animationsEnabled &&
      widget.trailingFadeEnabled &&
      (!_isComplete || _groupAnimationController.value < 1.0);

  List<FadeRun> _currentFadeRuns() => _engine.runs
      .map(
        (r) => FadeRun(
          r.start,
          r.end,
          Duration(microseconds: r.revealedAt.microsecondsSinceEpoch),
        ),
      )
      .toList(growable: false);

  bool get _fadeActive =>
      _fadeAllowed &&
      hasActiveFade(
        runs: _currentFadeRuns(),
        now: _now(),
        fadeDuration: widget.fadeInDuration,
      );

  // ---- Ticker (single, per Phase B seam) -------------------------------

  /// Whether the caret should currently be shown (DESIGN.md 4.2): revealing
  /// (or waiting for the first token), no error, and [StreamingText.showCursor]
  /// on. Hidden as soon as the reveal completes, so the final rendered text
  /// always equals the source with no trailing sentinel/widget span left in
  /// it.
  bool get _caretVisible =>
      widget.showCursor && !_isComplete && _error == null;

  /// The ticker only needs to run for animation *decoration* - the reveal
  /// itself is driven by [_scheduler]'s own timer. Reduced motion collapses
  /// all of it to static frames (DESIGN.md section 7): no fade curve, no
  /// caret pulse.
  bool get _needsTicking =>
      !_reducedMotion && (_scheduler.isRunning || _fadeActive || _caretVisible);

  void _syncTicker() {
    if (!mounted) return;
    if (_needsTicking) {
      _ticker ??= createTicker(_onTick);
      if (!_ticker!.isTicking) {
        _ticker!.start();
      }
    } else {
      _ticker?.stop();
    }
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final progress = _engine.isComplete
        ? 1.0
        : (_engine.progress >= 0.999 ? 0.999 : _engine.progress);
    widget.controller?.updateProgress(progress);
    setState(() {});
    widget.onTextChanged?.call();
    if (!_needsTicking) {
      _ticker?.stop();
    }
  }

  // ---- Lifecycle --------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _groupAnimationController = AnimationController(
      vsync: this,
      duration: widget.fadeInDuration,
    );
    _createEngineAndScheduler();
    widget.controller?.updateState(StreamingTextState.idle);
    widget.controller?.addListener(_handleControllerChange);
    _initSource();
  }

  @override
  void didUpdateWidget(covariant StreamingText oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 1. Controller swap (W22): unhook the old controller, hook the new one,
    // and sync its state to what this widget already reflects.
    if (!identical(widget.controller, oldWidget.controller)) {
      _swapController(oldWidget.controller);
    }

    // 2. Stream identity swap (covers stream->stream, stream->null,
    // null->stream): a fresh engine + scheduler, a fresh subscription.
    if (!identical(widget.stream, oldWidget.stream)) {
      _handleStreamSwap();
      return;
    }

    _syncEngineConfig();

    // 3. Stream set: config diffs (typingSpeed/chunkSize/wordByWord/
    // latexEnabled/speedMultiplier, applied above) take effect in place.
    // Never touch `_streamSubscription` here (W9) - `widget.text` is not
    // meaningful while streaming, so there is nothing else to do.
    if (widget.stream == null) {
      // 4. Text change (non-stream only): setSource keeps the common
      // prefix (W24) and never rewrites/loses already-revealed text (W2).
      if (widget.text != oldWidget.text) {
        _resetArabicCache();
        _engine.setSource(widget.text, closed: true);
      }
    }

    // 5. animationsEnabled turned off (or interval collapsed to zero):
    // reveal instantly.
    _applyImmediateRevealIfNeeded();

    _scheduler.wake();
    _syncTicker();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduced == _reducedMotion) return;
    _reducedMotion = reduced;
    if (_reducedMotion && !_isComplete && _error == null) {
      // Reduced motion behaves like `animationsEnabled: false`: reveal
      // instantly. Deferred to a post-frame callback since this can run
      // mid-build (e.g. in response to a MediaQuery change propagating down
      // the tree), and `_engine.revealAll()` may synchronously call
      // `setState` via `_handleEngineComplete`.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _engine.revealAll();
        });
        _scheduler.wake();
        _syncTicker();
      });
    } else {
      _syncTicker();
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _scheduler.dispose();
    _ticker?.dispose();
    _groupAnimationController.dispose();
    widget.controller?.removeListener(_handleControllerChange);
    super.dispose();
  }

  // ---- Build --------------------------------------------------------

  TextDirection get _effectiveTextDirection =>
      widget.textDirection ??
      (_containsArabic(_engine.revealed) ? TextDirection.rtl : TextDirection.ltr);

  @override
  Widget build(BuildContext context) {
    // Fires the single completion announcement (DESIGN.md section 6:
    // "exactly one announcement of the full source, or of the label, on
    // completion") exactly once per revealing-to-complete transition, purely
    // by observing `_isComplete` here on every rebuild - independent of
    // which code path (stream done, tap-to-complete, controller skipToEnd,
    // instant reveal) actually flipped it.
    if (_isComplete && _error == null) {
      if (!_announcedCompletion) {
        _announcedCompletion = true;
        final message = widget.semanticsLabel ?? _engine.revealed;
        final direction = _effectiveTextDirection;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          // `SemanticsService.announce` is deprecated in favor of
          // `sendAnnouncement` starting with a Flutter version newer than
          // this package's `>=3.32.0` floor, where `sendAnnouncement` does
          // not exist yet - `announce` is the only one available on both.
          // ignore: deprecated_member_use
          SemanticsService.announce(message, direction);
        });
      }
    } else {
      _announcedCompletion = false;
    }

    // The tap-to-complete `GestureDetector` is built inside `_buildContent`,
    // as a descendant of `SelectionArea` rather than an ancestor: a
    // `GestureDetector` wrapping a `SelectionArea` loses the tap to
    // `SelectionArea`'s own gesture recognizers in the arena, silently
    // breaking tap-to-complete whenever `selectable` is on.
    return _buildContent(context);
  }

  Widget _buildErrorContent(BuildContext context, Object error) {
    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(context, error);
    }
    final effectiveStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final revealedText = _engine.revealed;
    final errorColor = Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (revealedText.isNotEmpty)
          Text(
            revealedText,
            style: effectiveStyle,
            textDirection: _effectiveTextDirection,
          ),
        Text('Error: $error', style: TextStyle(color: errorColor)),
      ],
    );
  }

  Widget _wrapTrailingFade(Widget child) {
    if (!_trailingFadeAllowed) return child;
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
            final fadeStart = (bounds.height - fadeHeight).clamp(
              0.0,
              bounds.height,
            );
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
      child: child,
    );
  }

  /// Maps a resolved [TextAlign] onto an [AlignmentGeometry] for the block
  /// that positions the (possibly narrower-than-available-width) rendered
  /// content. Directional (`AlignmentDirectional`) rather than physical, so
  /// `start`/`end` follow the ambient [Directionality] instead of being
  /// hard-coded to left/right (W-a11y: "drop the forced right alignment").
  AlignmentGeometry _blockAlignmentFor(TextAlign align) {
    switch (align) {
      case TextAlign.right:
      case TextAlign.end:
        return AlignmentDirectional.centerEnd;
      case TextAlign.center:
      case TextAlign.justify:
        return Alignment.center;
      case TextAlign.left:
      case TextAlign.start:
        return AlignmentDirectional.centerStart;
    }
  }

  Widget _buildContent(BuildContext context) {
    final error = _error;
    final direction = _effectiveTextDirection;
    // DESIGN.md section 7: static full-opacity caret under reduced motion
    // (still hidden on completion, same as the pulsing case).
    final caretVisible = _caretVisible;
    Widget? caret;
    if (caretVisible) {
      final tokens = StreamingTokens.of(Theme.of(context).brightness);
      final caretColor = widget.cursorColor ?? tokens.textPrimary;
      final opacity = caretPulseOpacity(_now(), reducedMotion: _reducedMotion);
      caret = StreamingCaret(opacity: opacity, color: caretColor);
    }

    Widget content;
    if (error != null) {
      content = _buildErrorContent(context, error);
    } else {
      final effectiveStyle = widget.style ?? DefaultTextStyle.of(context).style;
      final revealedText = _engine.revealed;
      // W-a11y: `TextAlign.start` (not a hard-coded left/right guess) so the
      // renderer's own directional layout does the right thing for RTL.
      final alignment = widget.textAlign ?? TextAlign.start;

      if (widget.markdownEnabled) {
        final renderText =
            caretVisible ? '$revealedText$caretSentinel' : revealedText;
        final effectiveOptions = caretVisible
            ? withCaretPattern(widget.markdownOptions, caretInlinePattern(caret!))
            : widget.markdownOptions;

        final blockAlignment = _blockAlignmentFor(alignment);
        // W21: a `LayoutBuilder` that only forces a width when the incoming
        // constraint is bounded, instead of unconditionally requesting
        // `double.infinity` (which throws inside an unbounded ancestor such
        // as a bare `Row`).
        Widget markdownContent = LayoutBuilder(
          builder: (context, constraints) {
            final child = StreamingMarkdownView(
              text: renderText,
              isComplete: _isComplete,
              isStreaming: widget.stream != null && !_isComplete,
              style: widget.markdownStyleSheet,
              textDirection: direction,
              textAlign: widget.textAlign,
              textScaler: widget.textScaler,
              latexEnabled: widget.latexEnabled,
              latexStyle: widget.latexStyle,
              latexScale: widget.latexScale,
              options: effectiveOptions,
              imageBuilder: widget.imageBuilder,
              onLinkTap: widget.onLinkTap,
              codeBuilder: widget.codeBuilder,
              latexBuilder: widget.latexBuilder,
              sourceTagBuilder: widget.sourceTagBuilder,
              highlightBuilder: widget.highlightBuilder,
              linkBuilder: widget.linkBuilder,
              // ignore: deprecated_member_use_from_same_package
              components: widget.components,
              // ignore: deprecated_member_use_from_same_package
              inlineComponents: widget.inlineComponents,
            );
            if (!constraints.hasBoundedWidth) {
              return Align(alignment: blockAlignment, child: child);
            }
            return Container(
              width: constraints.maxWidth,
              alignment: blockAlignment,
              child: child,
            );
          },
        );
        markdownContent = _wrapTrailingFade(markdownContent);
        content = Directionality(
          textDirection: direction,
          child: markdownContent,
        );
      } else if (!_fadeAllowed && !caretVisible) {
        // No fade, no caret: the exact pre-existing plain-text widget shape
        // (a `Text` with `.data` set, not `Text.rich`), so callers/tests
        // that match on it are unaffected by this slice.
        final textContent = Text(
          revealedText,
          style: effectiveStyle,
          textAlign: alignment,
          textDirection: direction,
          softWrap: widget.softWrap ?? true,
          overflow: widget.overflow ?? TextOverflow.clip,
          textScaler: widget.textScaler ?? MediaQuery.textScalerOf(context),
          maxLines: widget.maxLines,
          strutStyle: widget.strutStyle,
        );
        content = _wrapTrailingFade(textContent);
      } else {
        final fadeDuration =
            _reducedMotion ? Duration.zero : widget.fadeInDuration;
        InlineSpan textSpan = _fadeAllowed
            ? buildFadeSpan(
                text: revealedText,
                runs: _currentFadeRuns(),
                now: _now(),
                fadeDuration: fadeDuration,
                curve: widget.fadeInCurve,
                style: effectiveStyle,
              )
            : TextSpan(text: revealedText, style: effectiveStyle);

        if (caretVisible) {
          // DESIGN.md 4.2: an inline `WidgetSpan`, baseline-aligned, with a
          // 4px leading gap - not on a new line.
          textSpan = TextSpan(
            style: effectiveStyle,
            children: [
              textSpan,
              const WidgetSpan(child: SizedBox(width: 4)),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: caret!,
              ),
            ],
          );
        }

        final textContent = Text.rich(
          textSpan,
          textAlign: alignment,
          textDirection: direction,
          softWrap: widget.softWrap ?? true,
          overflow: widget.overflow ?? TextOverflow.clip,
          textScaler: widget.textScaler ?? MediaQuery.textScalerOf(context),
          maxLines: widget.maxLines,
          strutStyle: widget.strutStyle,
        );
        content = _wrapTrailingFade(textContent);
      }
    }

    // Tap-to-complete: a GestureDetector wrapping the raw content, applied
    // BEFORE `SelectionArea` wraps it (see the comment on [build]) so
    // `selectable: true` doesn't silently break it.
    content = GestureDetector(
      onTap: widget.completeAnimationOnTap ? _handleTap : null,
      child: content,
    );

    if (widget.selectable) {
      content = SelectionArea(child: content);
    }

    // DESIGN.md section 6 / acceptance criterion 9: mid-stream text is
    // excluded from semantics; a supplied `semanticsLabel` always replaces
    // the raw text node (even once complete) rather than being read
    // alongside it.
    final label = widget.semanticsLabel;
    return Semantics(
      label: label,
      liveRegion: _isComplete,
      child: ExcludeSemantics(
        excluding: !_isComplete || label != null,
        child: content,
      ),
    );
  }
}
