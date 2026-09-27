import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:gpt_markdown/gpt_markdown.dart' hide RevealEngine;

import '../controller/streaming_text_controller.dart';
import '../engine/atomic_spans.dart';
import '../engine/reveal_engine.dart';
import '../engine/reveal_pacer.dart';
import '../engine/reveal_scheduler.dart';
import '../engine/unit_policy.dart';
import '../render/caret_inline.dart';
import '../render/fade_span.dart';
import '../render/markdown_fade_mask.dart';
import '../render/markdown_options.dart';
import '../render/markdown_renderer.dart';
import '../render/mend.dart' show MendState;
import '../render/render_scope.dart';
import '../render/streaming_caret.dart';
import '../theme/streaming_tokens.dart';
import 'reveal_mode.dart';

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
    this.revealMode = RevealMode.smoothFade,
    this.pacing,
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

  /// How revealed text arrives on screen (DESIGN.md section 4). Defaults to
  /// [RevealMode.smoothFade].
  ///
  /// Pass `revealMode: null` explicitly to opt OUT of every 2.0 reveal
  /// default and keep the pre-2.0 behaviour driven entirely by
  /// [wordByWord]/[fadeInEnabled]/[fadeInDuration]/[fadeInCurve]/
  /// [chunkSize]/[typingSpeed].
  final RevealMode? revealMode;

  /// How a `Stream<String>` (or static [text]) source is paced (DESIGN.md
  /// 4.3). When `null`, [stream] input defaults to [StreamPacing.catchUp]
  /// and static [text] input defaults to [StreamPacing.fixed] using
  /// [typingSpeed].
  final StreamPacing? pacing;

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

  /// Incremental `mend()` scan cache for this widget's stream (B1-S6 round
  /// 10 PERF slice - see [MendState]'s own doc comment). Created once and
  /// reused for the whole life of this `State`, so `mend()` only ever
  /// re-scans the NEW text on each markdown reveal tick instead of the
  /// whole revealed-so-far body. Lazy because plain-text (`markdownEnabled:
  /// false`) streams never call `mend()` at all and shouldn't pay even the
  /// allocation.
  MendState? _mendState;

  MendState get _ensureMendState => _mendState ??= MendState();

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

  /// Whether the *previous* [_onTick] rebuilt for reveal/fade activity (as
  /// opposed to a caret-only pulse). Kept so the tick where activity just
  /// stopped still gets exactly one more rebuild - otherwise the last
  /// rendered frame is whatever was on screen a tick before settling (e.g. a
  /// fade span frozen at ~0.999 opacity instead of the fully-opaque rest
  /// state) because the tick that observes "no longer active" never
  /// `setState`s to show it.
  bool _lastTickWasActive = false;

  /// The engine [RevealEngine.cursor] value as of the last [build]. Compared
  /// against the *current* cursor in [_onTick] so a tick always rebuilds
  /// when the reveal has actually moved on, even if [RevealScheduler] itself
  /// already self-stopped (`isRunning == false`) within that same tick -
  /// e.g. a short post-completion append that fits in a single scheduler
  /// tick and both reveals and idles before the widget's own [Ticker] frame
  /// callback runs. Relying on `_scheduler.isRunning` alone at that point
  /// would race and silently drop the frame that should have painted it.
  int _lastBuiltCursor = -1;

  /// A monotonic clock shared between [RevealEngine]'s reveal-run
  /// timestamps and this widget's fade rendering, so `now - revealedAt`
  /// stays consistent without needing wall-clock [DateTime] math.
  ///
  /// Driven from the single [_ticker]'s own `elapsed` (see [_onTick])
  /// instead of a wall-clock [Stopwatch]: under a real vsync it tracks
  /// frame time (and [timeDilation]) exactly as before, but under
  /// `flutter test` it advances only on pumped frames, so fade progress is a
  /// pure function of frames pumped rather than of real elapsed time and
  /// machine load. [Ticker.elapsed] itself resets to zero every time the
  /// ticker restarts ([Ticker.stop] clears its start time), so
  /// [_fadeClockOffset] carries the last observed value forward across
  /// stop/start cycles instead of ever going backward.
  Duration _fadeNow = Duration.zero;
  Duration _fadeClockOffset = Duration.zero;

  DateTime _engineClock() =>
      DateTime.fromMicrosecondsSinceEpoch(_fadeNow.inMicroseconds);

  Duration _now() => _fadeNow;

  /// Kept only for the trailing-edge [ShaderMask] dismiss animation
  /// ([StreamingText.trailingFadeEnabled]) — unrelated to the single-ticker
  /// per-glyph fade, and cheap: one bounded-duration controller, started
  /// once on completion, disposed with the state.
  late AnimationController _groupAnimationController;

  // Incremental "does the revealed text contain Arabic" cache: a static,
  // once-compiled RegExp, scanned only over the NEW suffix since the last
  // check (append-only growth is the common case) instead of re-scanning
  // the whole buffer - or recompiling a RegExp - on every tick (W-perf).
  static final RegExp _arabicRegex = RegExp(r'[؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]');
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

  /// Whether [RevealMode.smoothFade]/[RevealMode.wordFade] are in effect —
  /// both reveal in word units and drive a fade, differing only in
  /// duration/curve (see [_effectiveFadeDuration]/[_effectiveFadeCurve]).
  bool get _modeFadeEnabled =>
      widget.revealMode == RevealMode.smoothFade ||
      widget.revealMode == RevealMode.wordFade;

  UnitPolicy _buildPolicy() {
    final mode = widget.revealMode;
    if (mode == null) {
      if (widget.wordByWord) return const WordPolicy();
      final chunkSize = widget.chunkSize > 0 ? widget.chunkSize : 1;
      return CharPolicy(chunkSize: chunkSize);
    }
    switch (mode) {
      case RevealMode.smoothFade:
      case RevealMode.wordFade:
        return const WordPolicy();
      case RevealMode.typewriter:
        final chunkSize = widget.chunkSize > 0 ? widget.chunkSize : 1;
        return CharPolicy(chunkSize: chunkSize);
      case RevealMode.instant:
        // Irrelevant in practice: `_instantReveal`/`_revealInstantly` bypass
        // the policy entirely for this mode via `revealAll`/`step` looping.
        return const CharPolicy();
    }
  }

  Duration _effectiveIntervalFor(Duration base) {
    final multiplier = widget.controller?.speedMultiplier ?? 1.0;
    if (multiplier <= 0) return base;
    final micros = base.inMicroseconds / multiplier;
    if (!micros.isFinite) return Duration.zero;
    return Duration(microseconds: micros.round());
  }

  Duration _effectiveInterval() => _effectiveIntervalFor(widget.typingSpeed);

  /// Builds the [RevealPacer] in effect per [StreamingText.pacing]
  /// (acceptance criterion 10): an explicit override always wins; otherwise,
  /// with a non-null [StreamingText.revealMode] (the 2.0 reveal system),
  /// `Stream<String>` input defaults to [StreamPacing.catchUp] and static
  /// [StreamingText.text] input defaults to [StreamPacing.fixed].
  ///
  /// `revealMode: null` (legacy) never defaults to catch-up pacing on its
  /// own, regardless of [StreamingText.stream] - that keeps pre-2.0 stream
  /// callers on the exact one-unit-per-tick behaviour they had before this
  /// pacer existed, unless they opt in via an explicit [StreamingText.pacing].
  RevealPacer _buildPacer() {
    final catchUp = widget.pacing?.catchUpTuning;
    if (catchUp != null) {
      return CatchUpPacer(
        window: catchUp.window,
        k: catchUp.k,
        floorCharsPerSecond: catchUp.floorCharsPerSecond,
        drainWithin: catchUp.drainWithin,
      );
    }
    if (widget.pacing?.fixedTypingSpeed != null) {
      return const FixedPacer();
    }
    if (widget.revealMode != null && widget.stream != null) {
      return const CatchUpPacer();
    }
    return const FixedPacer();
  }

  /// The scheduler's tick interval for the current [_buildPacer] choice: a
  /// catch-up pacer ticks on its own window; a fixed pacer ticks once per
  /// (speed-multiplier-adjusted) typing interval.
  Duration _schedulerInterval() {
    final catchUp = widget.pacing?.catchUpTuning;
    if (catchUp != null) return catchUp.window;
    final fixedTyping = widget.pacing?.fixedTypingSpeed;
    if (fixedTyping != null) return _effectiveIntervalFor(fixedTyping);
    if (widget.revealMode != null && widget.stream != null) {
      return const Duration(milliseconds: 50);
    }
    return _effectiveInterval();
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
      interval: _schedulerInterval(),
      pacer: _buildPacer(),
    );
    // A brand new `RevealEngine` instance is itself a fresh document context
    // for `MarkdownFadeMask` - bump the counter directly (see `_fadeEpoch`'s
    // doc for why this can't be `_fadeEpochBase + _engine.epoch`) and record
    // the new engine's starting epoch (always 0) as the last value observed,
    // so the very next `_fadeEpoch` read doesn't mistake "a brand new engine
    // whose own epoch happens to read 0" for "no change happened".
    _fadeEpochCounter += 1;
    _lastEngineEpochSeen = _engine.epoch;
  }

  /// The strictly-increasing counter `_fadeEpoch` reads. Bumped directly by
  /// [_createEngineAndScheduler] (a brand new engine) and by [_fadeEpoch]
  /// itself the moment it observes [RevealEngine.epoch] change since the
  /// last read (the current engine's own non-prefix `setSource`/`reset`).
  int _fadeEpochCounter = 0;

  /// The value of [RevealEngine.epoch] last observed by [_fadeEpoch].
  int _lastEngineEpochSeen = 0;

  /// A monotonically-increasing signal `MarkdownFadeMask` watches to know
  /// when it must drop everything it has cached about "the document so
  /// far": bumped on a brand new `RevealEngine` (a stream swap) and on the
  /// current engine's own non-prefix `setSource` (a `text:` param replaced
  /// with unrelated content). See `RevealEngine.epoch`'s doc for why a
  /// rendered-text-only diff can't safely infer this on its own.
  ///
  /// This is a genuinely monotonic COUNTER, bumped by exactly one per
  /// observed change - it is deliberately NOT `_fadeEpochBase +
  /// _engine.epoch` (an earlier version of this getter): that sum is not
  /// strictly increasing across an engine swap. `RevealEngine.epoch` resets
  /// to 0 on every new engine, so e.g. base=1 with the old engine having
  /// reached its own epoch 2 (`_fadeEpoch == 3`) followed by a swap
  /// (`_fadeEpochBase` becomes 2, the new engine's own epoch starts at 0,
  /// `_fadeEpoch == 2`) makes the "epoch" the mask observes go 3 -> 2, i.e.
  /// DECREASE - `MarkdownFadeMask.epoch`'s setter only clears cached state
  /// on a value CHANGE, not specifically an increase, so this particular
  /// decrease happened to still clear correctly, but a same-length replay
  /// (e.g. swap back to a `RevealEngine` state that reproduces the same sum)
  /// could silently collide with a prior value and fail to clear at all.
  /// Reading this getter itself detects a same-engine epoch bump (a
  /// non-prefix `setSource`/`reset` on the CURRENT engine, which doesn't go
  /// through [_createEngineAndScheduler]) and bumps the counter by exactly
  /// one right then, so the sequence "text A -> unrelated text B (same
  /// engine) -> swap to a stream (new engine)" strictly increases:
  /// 0 -> 1 -> 2, never repeating or decreasing.
  int get _fadeEpoch {
    final engineEpoch = _engine.epoch;
    if (engineEpoch != _lastEngineEpochSeen) {
      _fadeEpochCounter += 1;
      _lastEngineEpochSeen = engineEpoch;
    }
    return _fadeEpochCounter;
  }

  void _syncEngineConfig() {
    _engine.policy = _buildPolicy();
    _engine.atomicSpans =
        widget.latexEnabled ? const AtomicSpanDetector() : null;
    _scheduler.pacer = _buildPacer();
    _scheduler.interval = _schedulerInterval();
  }

  bool get _instantReveal =>
      _reducedMotion ||
      !widget.animationsEnabled ||
      widget.revealMode == RevealMode.instant ||
      _effectiveInterval() == Duration.zero;

  /// Reveals as much as can be shown right now with no animation.
  ///
  /// `animationsEnabled: false` / a zero `typingSpeed` keep their pre-W26
  /// contract: reveal the *entire* current source immediately via
  /// [RevealEngine.revealAll], bypassing open-input withholding altogether -
  /// existing callers (W23/W26) rely on a mid-stream chunk showing up in
  /// full the instant it arrives, with no held-back tail.
  ///
  /// Reduced motion is different: it isn't "no animation", it's "no
  /// ticker" - there is no per-frame driver left to reveal a withheld tail
  /// once more input closes the gap, so while input is still open it goes
  /// through [RevealEngine.step] instead, which respects the same
  /// grapheme/word/atomic-span safety a normal typewriter reveal would (see
  /// DESIGN.md section 7). [_onStreamDone] re-runs this once input closes,
  /// which is what releases that tail.
  void _revealInstantly() {
    if (_reducedMotion && !_engine.inputClosed) {
      while (_engine.step()) {}
    } else {
      _engine.revealAll();
    }
  }

  void _applyImmediateRevealIfNeeded() {
    if (_instantReveal) {
      _revealInstantly();
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
      // Closing releases any reduced-motion/instant-reveal holdback that
      // was only withheld because more input could still arrive (the final
      // grapheme, an unterminated word) - without this, reduced motion with
      // an open-then-closed stream would leave that tail stuck forever with
      // no ticker running to reveal it later.
      _applyImmediateRevealIfNeeded();
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

  /// The plain-text fade duration in effect: [RevealMode.smoothFade] and
  /// [RevealMode.wordFade] use their own DESIGN.md-tuned durations
  /// (ignoring [StreamingText.fadeInDuration]); a `null` [revealMode] keeps
  /// the legacy [StreamingText.fadeInDuration].
  Duration get _effectiveFadeDuration {
    switch (widget.revealMode) {
      case RevealMode.smoothFade:
        return smoothFadeDuration;
      case RevealMode.wordFade:
        return wordFadeDuration;
      case RevealMode.typewriter:
      case RevealMode.instant:
      case null:
        return widget.fadeInDuration;
    }
  }

  /// The plain-text fade curve in effect - see [_effectiveFadeDuration].
  Curve get _effectiveFadeCurve {
    switch (widget.revealMode) {
      case RevealMode.smoothFade:
        return smoothFadeCurve;
      case RevealMode.wordFade:
        return wordFadeCurve;
      case RevealMode.typewriter:
      case RevealMode.instant:
      case null:
        return widget.fadeInCurve;
    }
  }

  /// Whether the plain-text (`buildFadeSpan`) fade path is allowed at all.
  ///
  /// [RevealMode.smoothFade] fades on Arabic too (acceptance criterion 9);
  /// only the legacy (`revealMode: null`) path suppresses fading Arabic
  /// content, per its pre-existing contract.
  bool get _fadeAllowed {
    if (!widget.animationsEnabled || widget.markdownEnabled) return false;
    if (widget.revealMode != null) return _modeFadeEnabled;
    return widget.fadeInEnabled && !_containsArabic(_engine.revealed);
  }

  bool get _trailingFadeAllowed =>
      widget.animationsEnabled &&
      widget.trailingFadeEnabled &&
      (!_isComplete || _groupAnimationController.value < 1.0);

  /// B1-S6: whether the cheap, paint-only markdown word-fade
  /// ([MarkdownFadeMask]) is in effect. `gpt_markdown`'s own
  /// `animation: fade` was rejected (see [markdownRevealFadeEnabled]'s
  /// wiring in `_buildContent` and doc/BENCHMARKS.md) for blowing the
  /// element-rebuild budget; this instead tracks the *rendered* paragraph's
  /// own growth (see `markdown_fade_mask.dart`'s doc for why - a verify
  /// round flagged the original source-offset mapping as mis-dimming
  /// settled words whenever markdown syntax made the rendered text shorter
  /// than the source) and applies it via a [RenderProxyBox]-level paint
  /// mask instead of rebuilding `GptMarkdown`'s span tree.
  bool get _markdownFadeAllowed =>
      widget.animationsEnabled &&
      widget.markdownEnabled &&
      !_reducedMotion &&
      _modeFadeEnabled;

  /// A generous safety margin added on top of [_effectiveFadeDuration] only
  /// for the "should the shared ticker keep running" decision below - never
  /// for [MarkdownFadeMask]'s own paint-time alpha math.
  ///
  /// [MarkdownFadeMask] times its runs from when the *rendered* paragraph's
  /// text actually grows, which is only ever observed from `performLayout`
  /// - i.e. one build/layout cycle AFTER the reveal engine's own
  /// [_engine.runs] entry was created (the engine updates synchronously
  /// inside [RevealScheduler]'s `Timer` callback; the render object only
  /// finds out once that triggers a rebuild). If the ticking decision used
  /// the engine's un-padded fade window, a scheduler tick that both reveals
  /// AND immediately idles within one `Timer` callback (a short burst that
  /// finishes in a single step - exactly this single-word smooth_fade
  /// scenario) could have the ticker's OWN `_onTick` observe
  /// `_scheduler.isRunning == false` and the not-yet-laid-out mask's
  /// `_engine`-based window already expired in the very same frame the
  /// paragraph's fade run is about to be created in - stopping the ticker
  /// before the mask ever gets a chance to animate at all. Padding the
  /// window with a couple of frames' worth of slack costs nothing (idle
  /// frames are cheap; [MarkdownFadeMask] itself is still the one deciding
  /// exactly what and how much to dim) and closes that race.
  static const Duration _markdownTickingSlack = Duration(milliseconds: 64);

  bool get _markdownFadeActive =>
      _markdownFadeAllowed &&
      hasActiveFade(
        runs: _currentFadeRuns(),
        now: _now(),
        fadeDuration: _effectiveFadeDuration + _markdownTickingSlack,
      );

  /// Notified every ticker frame while [_markdownFadeActive] might be true,
  /// so [MarkdownFadeMask] repaints itself directly - never via `setState`,
  /// which would rebuild the whole `GptMarkdown` subtree for no reason (the
  /// exact cost this slice exists to avoid).
  final _RepaintSignal _markdownFadeRepaint = _RepaintSignal();

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
        fadeDuration: _reducedMotion ? Duration.zero : _effectiveFadeDuration,
      );

  // ---- Ticker (single, per Phase B seam) -------------------------------

  /// Whether the caret should currently be shown (DESIGN.md 4.2): revealing
  /// (or waiting for the first token), no error, and [StreamingText.showCursor]
  /// on. Hidden as soon as the reveal completes, so the final rendered text
  /// always equals the source with no trailing sentinel/widget span left in
  /// it.
  bool get _caretVisible => widget.showCursor && !_isComplete && _error == null;

  /// The ticker only needs to run for animation *decoration* - the reveal
  /// itself is driven by [_scheduler]'s own timer. Reduced motion collapses
  /// all of it to static frames (DESIGN.md section 7): no fade curve, no
  /// caret pulse.
  bool get _needsTicking =>
      !_reducedMotion &&
      (_scheduler.isRunning ||
          _fadeActive ||
          _markdownFadeActive ||
          _caretVisible);

  void _syncTicker() {
    if (!mounted) return;
    if (_needsTicking) {
      _ticker ??= createTicker(_onTick);
      if (!_ticker!.isTicking) {
        // `Ticker.elapsed` resets to zero on the frame after `start()` -
        // carry the last known fade-clock value forward so `_fadeNow` keeps
        // advancing monotonically across this stop/start cycle instead of
        // jumping back to (near) zero.
        _fadeClockOffset = _fadeNow;
        _ticker!.start();
      }
    } else {
      _ticker?.stop();
    }
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    _fadeNow = _fadeClockOffset + elapsed;
    final progress =
        _engine.isComplete
            ? 1.0
            : (_engine.progress >= 0.999 ? 0.999 : _engine.progress);
    widget.controller?.updateProgress(progress);

    // The caret pulse alone never needs a full `setState`: it updates
    // [_caretOpacity] directly, which [StreamingCaret] listens to and
    // repaints from by itself (W-perf: the whole point is that a pulsing
    // caret must not re-run the markdown segment cache 60x/sec while a 20k+
    // char document streams in behind it).
    if (_caretVisible) {
      _caretOpacity.value = caretPulseOpacity(
        _now(),
        reducedMotion: _reducedMotion,
      );
    }

    // Wake [MarkdownFadeMask] up directly (paint-only, no `setState`) so a
    // fade can keep settling after the scheduler itself has gone idle -
    // e.g. the last word of a burst still fading out after the stream
    // paused - without re-running `gpt_markdown`'s segment cache.
    //
    // PERF (B1-S6 round 10): gated on [_markdownFadeActive], not merely
    // `widget.markdownEnabled` - the ticker keeps running for the WHOLE
    // stream whenever the caret is visible (`_needsTicking`'s
    // `_caretVisible` clause), which is most of a typical reveal. Pinging
    // unconditionally called `markNeedsPaint()` on the mask's
    // `RenderProxyBox` every single tick even when no run was actually
    // fading, forcing a full repaint of the entire (potentially 20k-char)
    // markdown subtree 60x/sec for no visual effect. `_markdownFadeActive`
    // already answers "is a run still within its fade window, plus the
    // ticking safety slack" - the exact condition under which a repaint can
    // possibly change anything - so gating on it drops the ping (and the
    // repaint it causes) to zero cost outside an active fade window, with
    // no correctness change: [_collectDims] was already a no-op on those
    // frames, this only stops making the render tree redundantly repaint to
    // discover that.
    if (widget.markdownEnabled && _markdownFadeActive) {
      _markdownFadeRepaint.ping();
    }

    // Only reveal progress and fade settling actually change what
    // `_buildContent` renders - rebuild for those, not for every tick. Still
    // rebuild the one tick right after activity stops (`_lastTickWasActive`)
    // so the settled/fully-opaque frame actually gets drawn, rather than
    // freezing on whatever was on screen mid-fade.
    //
    // `_scheduler.isRunning` alone is racy: a short append can be entirely
    // revealed and idle the scheduler within a single `Timer` tick, before
    // this `Ticker` frame callback even runs - so also compare the engine's
    // cursor against what the last `build` actually rendered, and rebuild
    // whenever it moved, independent of whether the scheduler still
    // considers itself "running" at the moment this tick observes it.
    final cursorMoved = _engine.cursor != _lastBuiltCursor;
    final isActive = _scheduler.isRunning || _fadeActive || cursorMoved;
    if (isActive || _lastTickWasActive) {
      setState(() {});
      widget.onTextChanged?.call();
    }
    _lastTickWasActive = isActive;
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
    //
    // Compared with `!=`, not `identical()` (W9): `StreamController.stream`
    // returns a NEW wrapper object on every access (`identical` is always
    // false) even though it's `==`-equal (compares the same underlying
    // controller) - so a caller who reads `stream: controller.stream`
    // directly inside `build()`, instead of caching the `Stream` in a field,
    // would otherwise look like a genuine stream swap on every single
    // rebuild (any config change, an ancestor rebuild, ...), tearing down
    // and re-subscribing a single-subscription stream that can only ever be
    // listened to once - throwing "Stream has already been listened to".
    if (widget.stream != oldWidget.stream) {
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
          _revealInstantly();
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
    _markdownFadeRepaint.dispose();
    _caretOpacityNotifier?.dispose();
    widget.controller?.removeListener(_handleControllerChange);
    super.dispose();
  }

  // ---- Caret (markdown-cache-safe, Phase C perf fix) --------------------

  /// The caret's opacity, updated in place every pulse frame instead of
  /// forcing a `setState` on the whole widget (see [_onTick]). [StreamingCaret]
  /// listens to this directly, so a pulsing caret repaints only itself - not
  /// the markdown subtree, which would otherwise re-run `gpt_markdown`'s
  /// segment cache on every frame for no visible reason.
  ValueNotifier<double>? _caretOpacityNotifier;

  ValueNotifier<double> get _caretOpacity =>
      _caretOpacityNotifier ??= ValueNotifier<double>(1.0);

  /// One [InlinePattern] instance reused for the lifetime of this State.
  ///
  /// `gpt_markdown`'s segment cache drops everything whenever
  /// `inlinePatterns` fails `listEquals` against the previous build - which,
  /// since [InlinePattern] has no value equality, means "the same object
  /// reference" (see `GptMarkdownConfig.isSame`). Building a new
  /// [InlinePattern] (and a new backing `RegExp`) every frame the caret pulses
  /// was exactly what defeated the cache; this field, plus the builder
  /// indirection in [_caretInlinePattern], is what keeps its identity stable
  /// while what it renders (the caret's color, fed by [_caretWidgetBuilder])
  /// still tracks the current build.
  InlinePattern? _caretInlinePatternInstance;

  /// What [_caretInlinePatternInstance]'s builder actually calls. Reassigned
  /// on every build that shows a caret (cheap: a field write, not a widget
  /// rebuild) so the *pattern* stays identical while the *caret it draws*
  /// stays current.
  Widget Function()? _caretWidgetBuilder;

  InlinePattern _ensureCaretInlinePattern() {
    return _caretInlinePatternInstance ??= caretInlinePattern(
      () => _caretWidgetBuilder!(),
    );
  }

  /// The [MarkdownRenderOptions] actually handed to [StreamingMarkdownView]
  /// while the caret is visible: [widget.markdownOptions] plus the cached
  /// caret pattern, appended - but only rebuilt (a cheap object allocation
  /// either way, kept cheap so the *pattern* stays the identical instance)
  /// when [widget.markdownOptions] itself changes identity, so an unrelated
  /// rebuild (a caret pulse, a reveal tick) reuses the exact same
  /// [MarkdownRenderOptions] object too.
  MarkdownRenderOptions? _cachedEffectiveOptions;
  MarkdownRenderOptions? _cachedBaseOptions;
  bool _cachedBaseOptionsSet = false;

  MarkdownRenderOptions _effectiveMarkdownOptions() {
    if (!_cachedBaseOptionsSet ||
        !identical(_cachedBaseOptions, widget.markdownOptions)) {
      _cachedBaseOptions = widget.markdownOptions;
      _cachedBaseOptionsSet = true;
      _cachedEffectiveOptions = withCaretPattern(
        widget.markdownOptions,
        _ensureCaretInlinePattern(),
      );
    }
    return _cachedEffectiveOptions!;
  }

  // ---- Build --------------------------------------------------------

  TextDirection get _effectiveTextDirection =>
      widget.textDirection ??
      (_containsArabic(_engine.revealed)
          ? TextDirection.rtl
          : TextDirection.ltr);

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
    final content = _buildContent(context);
    // Recorded post-build so [_onTick] can tell "the engine moved since we
    // last actually painted it" apart from "the scheduler still thinks it's
    // running" (see [_lastBuiltCursor]'s doc).
    _lastBuiltCursor = _engine.cursor;
    return content;
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
    if (caretVisible) {
      final tokens = StreamingTokens.of(Theme.of(context).brightness);
      final caretColor = widget.cursorColor ?? tokens.textPrimary;
      // Keep the shared notifier correct even on a build the ticker didn't
      // cause (text growth, a reduced-motion toggle, a theme change): the
      // ticker (see [_onTick]) is what updates it on every pulse frame in
      // between, without triggering a rebuild of its own.
      _caretOpacity.value = caretPulseOpacity(
        _now(),
        reducedMotion: _reducedMotion,
      );
      // Rebind what the cached inline pattern (see
      // [_ensureCaretInlinePattern]) actually builds to THIS build's color,
      // without touching the pattern's own identity. Left un-invoked here -
      // only called lazily, below, wherever a caret widget is actually
      // needed - so the markdown branch (which never reads `caret` directly,
      // only `_effectiveMarkdownOptions()`'s cached pattern) doesn't pay for
      // a `StreamingCaret` instance it throws away unused on every frame.
      _caretWidgetBuilder =
          () => StreamingCaret(opacity: _caretOpacity, color: caretColor);
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
        // Reuses one cached `InlinePattern`/`MarkdownRenderOptions` pair
        // across builds (see [_effectiveMarkdownOptions]) instead of
        // allocating fresh ones every frame: `gpt_markdown`'s segment cache
        // keys `inlinePatterns` on element *identity* (`InlinePattern` has no
        // value equality), so a fresh instance every tick looked like a
        // config change on every frame and dropped the whole cache.
        final effectiveOptions =
            caretVisible ? _effectiveMarkdownOptions() : widget.markdownOptions;

        final blockAlignment = _blockAlignmentFor(alignment);

        // PHASE-B1-PLAN.md's decision rule (acceptance criterion 11):
        // "adopt the hybrid if the markdown stream is <=1.8x bare ... .
        // Otherwise markdown smoothFade becomes word-paced with no alpha".
        // B1-S4's own benchmark measured the hybrid in isolation (a mock
        // growing `GptMarkdown` with no caret and no real `RevealEngine`)
        // and got ~1.4x, so doc/BENCHMARKS.md recorded "HYBRID ADOPTED".
        // Wiring it into the REAL `StreamingText` for this slice and
        // re-measuring on `test/perf/stream_benchmark_test.dart` (the
        // default-caret-on, real-engine benchmark) instead showed ~2.3x
        // time and ~12.9x element-rebuild ratio — both over budget (1.8x /
        // 6x) — because `gpt_markdown`'s own per-frame reveal ticker keeps
        // restyling still-fading spans independently of our engine's
        // ticks, compounding with the caret and the catch-up pacer's own
        // per-tick work. That contradicts S4's isolated measurement, so
        // this slice's own (more representative) numbers win: the hybrid
        // is REJECTED for the shipped default. Markdown `smoothFade`/
        // `wordFade` still reveal word-paced (via `WordPolicy` + the
        // catch-up pacer below) with no `gpt_markdown` alpha - exactly the
        // rule's "otherwise" branch. See doc/BENCHMARKS.md's "B1-S5
        // correction" section for the numbers. Kept as a `false` constant
        // (not simply omitted) so the wiring below stays in place as a
        // seam if a future `gpt_markdown` release makes the hybrid cheap
        // enough to re-adopt.
        const markdownRevealFadeEnabled = false;
        final markdownRevealFadeSeconds =
            widget.revealMode == RevealMode.wordFade
                ? wordFadeDuration.inMicroseconds /
                    Duration.microsecondsPerSecond
                : smoothFadeDuration.inMicroseconds /
                    Duration.microsecondsPerSecond;

        // W21: a `LayoutBuilder` that only forces a width when the incoming
        // constraint is bounded, instead of unconditionally requesting
        // `double.infinity` (which throws inside an unbounded ancestor such
        // as a bare `Row`).
        Widget markdownContent = LayoutBuilder(
          builder: (context, constraints) {
            final child = StreamingMarkdownView(
              text: renderText,
              isComplete: _isComplete,
              isStreaming: !_isComplete,
              revealFadeEnabled: markdownRevealFadeEnabled,
              revealFadeSeconds: markdownRevealFadeSeconds,
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
              mendState: _ensureMendState,
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
        if (_markdownFadeAllowed) {
          markdownContent = MarkdownFadeMask(
            enabled: true,
            epoch: _fadeEpoch,
            now: _now,
            fadeDuration: _effectiveFadeDuration,
            curve: _effectiveFadeCurve,
            repaint: _markdownFadeRepaint,
            child: markdownContent,
          );
        }
        markdownContent = _wrapTrailingFade(markdownContent);
        content = Directionality(
          textDirection: direction,
          child: StreamingRenderScope(
            isStreaming: !_isComplete,
            isComplete: _isComplete,
            caretBuilder: caretVisible ? _caretWidgetBuilder : null,
            child: markdownContent,
          ),
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
            _reducedMotion ? Duration.zero : _effectiveFadeDuration;
        InlineSpan textSpan =
            _fadeAllowed
                ? buildFadeSpan(
                  text: revealedText,
                  runs: _currentFadeRuns(),
                  now: _now(),
                  fadeDuration: fadeDuration,
                  curve: _effectiveFadeCurve,
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
                child: _caretWidgetBuilder!(),
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

/// A [ChangeNotifier] that only ever exposes a public "wake up" ping -
/// [MarkdownFadeMask] listens to it directly to repaint itself, without
/// [StreamingText] needing `@protected` access to `notifyListeners` from
/// outside a [ChangeNotifier] subclass.
class _RepaintSignal extends ChangeNotifier {
  void ping() => notifyListeners();
}
