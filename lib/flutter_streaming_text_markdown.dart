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
export 'src/render/markdown_options.dart';
export 'src/widgets/streaming_shimmer.dart' show StreamingShimmer;

// Re-exported because they appear in [MarkdownRenderOptions]'s public
// signatures (builders, style types); callers need these names in scope to
// construct a [MarkdownRenderOptions] without a separate `gpt_markdown`
// import.
export 'package:gpt_markdown/gpt_markdown.dart'
    show
        MarkdownComponent,
        GptMarkdownStyleSheet,
        InlineCodeStyle,
        HeadingBuilder,
        TableBuilder,
        BlockQuoteBuilder,
        OrderedListBuilder,
        UnOrderedListBuilder,
        HrBuilder,
        CheckboxBuilder,
        RadioOptionBuilder,
        MarkdownBlockComponent,
        InlinePattern,
        InlineDirective,
        InlineCodeBuilder,
        InlineLinkBuilder,
        InlineSourceTagBuilder,
        ImageBuilder;
import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart' show MarkdownComponent;
import 'src/streaming/streaming_text.dart';
import 'src/streaming/reveal_mode.dart';
import 'src/theme/streaming_text_theme.dart';
import 'src/controller/streaming_text_controller.dart';
import 'src/presets/animation_presets.dart';
import 'src/render/markdown_options.dart';
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
/// Provide either [text] (static markdown string, the default) or [stream]
/// (a `Stream<String>` of chunks from an LLM API). When [stream] is
/// non-null, [text] is ignored entirely — the stream starts from an empty
/// buffer and content is appended as it emits.
///
/// Use [typingSpeed] to control how fast each character or word appears, and
/// [wordByWord] to choose between character-by-character or word-by-word
/// animation. For unbounded streams, prefer [trailingFadeEnabled] over
/// [fadeInEnabled] — per-character fades are auto-disabled when [stream] is
/// set to avoid spawning one [AnimationController] per glyph.
class StreamingTextMarkdown extends StatefulWidget {
  /// The text to display. Ignored when [stream] is also provided — the
  /// stream starts from an empty buffer, not from [text].
  final String text;

  /// Optional stream of text chunks from an LLM API (OpenAI, Anthropic,
  /// Ollama, etc.). Each emitted string is appended to the rendered text and
  /// animated using the active typing settings. When this is non-null the
  /// inner streaming engine takes over, [text] is ignored, and
  /// per-character [fadeInEnabled] is suppressed automatically; use
  /// [trailingFadeEnabled] for a smooth reveal.
  ///
  /// ```dart
  /// StreamingTextMarkdown(
  ///   stream: chatService.streamReply(prompt),
  ///   markdownEnabled: true,
  ///   trailingFadeEnabled: true,
  /// )
  /// ```
  final Stream<String>? stream;

  /// Initial text to display before the animation starts.
  @Deprecated(
    'Never displayed. text is the sole rendered/initial-buffer source; '
    'this field has no effect. Will be removed in 2.0.0.',
  )
  final String initialText;

  /// Markdown style configuration: a plain [TextStyle] applied to the
  /// markdown renderer as its base text style. Distinct from
  /// [MarkdownRenderOptions.styleSheet] (in [markdownOptions]), which is a
  /// `gpt_markdown` `GptMarkdownStyleSheet` for per-component styling
  /// (headings, tables, block quotes, etc.).
  final TextStyle? styleSheet;

  /// Custom theme for the widget
  final StreamingTextTheme? theme;

  /// Padding around the text
  final EdgeInsets? padding;

  /// Whether to scroll automatically as new text arrives
  final bool autoScroll;

  /// Whether each character (or word, in word-by-word mode) fades in as it is
  /// revealed. Disabled automatically for Arabic/RTL content. For stream-based
  /// usage in [StreamingText], use [trailingFadeEnabled] instead.
  final bool fadeInEnabled;

  /// Duration of the fade-in animation
  final Duration fadeInDuration;

  /// The curve to use for the fade-in animation
  final Curve fadeInCurve;

  /// Whether to stream text word by word instead of character by character
  final bool wordByWord;

  /// The number of grapheme clusters revealed per animation tick when
  /// [wordByWord] is `false`. Ignored in word-by-word mode, where one unit
  /// is a whole word instead. A very large value (see
  /// [StreamingTextMarkdown.instant]) reveals effectively everything on the
  /// first tick.
  final int chunkSize;

  /// The speed at which each character or word appears
  final Duration typingSpeed;

  /// The text direction
  final TextDirection? textDirection;

  /// The text alignment
  final TextAlign? textAlign;

  /// Whether to enable markdown rendering.
  ///
  /// Defaults to `false` here — note this differs from the inner
  /// [StreamingText] widget, whose own `markdownEnabled` defaults to `true`
  /// when used directly. [StreamingTextMarkdown] always forwards its own
  /// value explicitly, so this mismatch has no runtime effect through this
  /// widget; it only matters if you construct [StreamingText] yourself.
  final bool markdownEnabled;

  /// Whether to enable LaTeX rendering
  final bool latexEnabled;

  /// Custom style for LaTeX expressions
  final TextStyle? latexStyle;

  /// Scale factor for LaTeX equations
  final double latexScale;

  /// Whether to enable fade-in animations for LaTeX content.
  @Deprecated(
    'No-op. LaTeX rendering is delegated to gpt_markdown, which has no '
    'per-run fade hook of its own; use latexBuilder to control LaTeX '
    'rendering directly. Will be removed in 2.0.0.',
  )
  final bool? latexFadeInEnabled;

  /// Controller for programmatic animation control
  final StreamingTextController? controller;

  /// Callback when animation completes
  final VoidCallback? onComplete;

  /// Whether animations are enabled. When false, text appears instantly.
  final bool animationsEnabled;

  /// Whether to show a trailing gradient fade at the bottom edge while text is
  /// streaming. The fade animates away when streaming completes (using
  /// [fadeInDuration] / [fadeInCurve] for the dismiss animation). Recommended
  /// for stream-based usage and works with markdown + RTL content.
  /// Defaults to `false`.
  final bool trailingFadeEnabled;

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

  /// Custom block-level markdown components forwarded to `gpt_markdown`'s
  /// `GptMarkdown.components`. Use this to override how headers, lists,
  /// bold, italic, tables, etc. are rendered. When `null`, the default
  /// `gpt_markdown` component list is used.
  @Deprecated(
    'Use markdownOptions.blockComponents. Passing components at all (even '
    'an empty list) switches gpt_markdown onto its legacy regex pipeline, '
    'which has no incremental segment cache. Will be removed in 2.0.0.',
  )
  final List<MarkdownComponent>? components;

  /// Custom inline markdown components forwarded to `gpt_markdown`'s
  /// `GptMarkdown.inlineComponents`. When `null`, the default inline
  /// component list is used.
  @Deprecated(
    'Use markdownOptions.inlinePatterns. Passing inlineComponents at all '
    '(even an empty list) switches gpt_markdown onto its legacy regex '
    'pipeline, which has no incremental segment cache. '
    'Will be removed in 2.0.0.',
  )
  final List<MarkdownComponent>? inlineComponents;

  /// Bundles `gpt_markdown` 1.3 pass-throughs that don't have a dedicated
  /// top-level parameter of their own (style sheet, block/inline builders,
  /// autolink config, ...). Forwarded as-is to the inner [StreamingText]. See
  /// [MarkdownRenderOptions].
  final MarkdownRenderOptions? markdownOptions;

  /// Whether the rendered text can be selected by the user (wraps the
  /// output in a `SelectionArea`). Defaults to `false`.
  final bool selectable;

  /// Whether to show a blinking cursor at the end of the text while
  /// animating. When `null` (the default), resolves to `stream != null` —
  /// a cursor makes sense for a live stream but not for static text.
  final bool? showCursor;

  /// Color of the blinking cursor shown while [showCursor] resolves to
  /// `true`. Defaults to the theme's text-primary token.
  final Color? cursorColor;

  /// Semantic label used for accessibility. When set, this label (rather
  /// than the revealed text itself) is what's announced/exposed to
  /// assistive technology.
  final String? semanticsLabel;

  /// Builder invoked when [stream] emits an error. Receives the error
  /// object; the text revealed so far stays on screen either way.
  ///
  /// When `null`, a default view is shown: the text revealed so far, plus a
  /// trailing `Error: $error` line in `Theme.of(context).colorScheme.error`.
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  /// Whether tapping the widget jumps the animation to completion.
  ///
  /// Defaults to `true`. Set to `false` to let the animation play through
  /// uninterrupted regardless of taps.
  final bool? completeAnimationOnTap;

  /// How revealed text arrives on screen (DESIGN.md section 4). Defaults to
  /// [RevealMode.smoothFade] on this constructor, [.chatGPT] and [.claude].
  /// [.typewriter] and [.instant] default to their own matching mode.
  ///
  /// Pass `revealMode: null` explicitly to opt OUT of every 2.0 reveal
  /// default and keep the pre-2.0 behaviour driven entirely by the legacy
  /// [wordByWord]/[fadeInEnabled]/[fadeInDuration]/[fadeInCurve]/
  /// [chunkSize]/[typingSpeed] parameters — see doc/MIGRATION.md.
  final RevealMode? revealMode;

  /// How a `Stream<String>` (or static [text]) source is paced (DESIGN.md
  /// 4.3). When `null`, [stream] input defaults to [StreamPacing.catchUp]
  /// and static [text] input defaults to [StreamPacing.fixed] using
  /// [typingSpeed].
  final StreamPacing? pacing;

  /// Creates a streaming markdown text widget.
  ///
  /// Provide [text] for static content, or [stream] to append chunks as they
  /// arrive from an LLM API. See the individual field docs above for
  /// animation, theming, and markdown/LaTeX options.
  const StreamingTextMarkdown({
    super.key,
    this.text = '',
    this.stream,
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
    this.trailingFadeEnabled = false,
    this.isLoading = false,
    this.shimmerLineCount = 3,
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
    this.selectable = false,
    this.showCursor,
    this.cursorColor,
    this.semanticsLabel,
    this.errorBuilder,
    this.completeAnimationOnTap,
    this.revealMode = RevealMode.smoothFade,
    this.pacing,
  });

  /// Creates a StreamingTextMarkdown with ChatGPT-style animation
  /// Perfect for fast, character-by-character streaming like ChatGPT
  ///
  /// [fadeInDuration], [fadeInCurve], and [typingSpeed] override the preset's
  /// defaults (150ms/easeOut fade, 15ms typing speed) when provided — leave
  /// them `null` to keep the ChatGPT preset's tuned values ([#17]).
  ///
  /// [#17]: https://github.com/hooshyar/flutter_streaming_text_markdown/issues/17
  const StreamingTextMarkdown.chatGPT({
    super.key,
    this.text = '',
    this.stream,
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
    this.trailingFadeEnabled = false,
    this.isLoading = false,
    this.shimmerLineCount = 3,
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
    this.selectable = false,
    this.showCursor,
    this.cursorColor,
    this.semanticsLabel,
    this.errorBuilder,
    this.completeAnimationOnTap,
    this.revealMode = RevealMode.smoothFade,
    this.pacing,
    Duration? fadeInDuration,
    Curve? fadeInCurve,
    Duration? typingSpeed,
  }) : fadeInEnabled = true,
       fadeInDuration = fadeInDuration ?? const Duration(milliseconds: 150),
       fadeInCurve = fadeInCurve ?? Curves.easeOut,
       wordByWord = false,
       chunkSize = 1,
       typingSpeed = typingSpeed ?? const Duration(milliseconds: 15);

  /// Creates a StreamingTextMarkdown with Claude-style animation
  /// Perfect for smooth, word-by-word streaming like Claude
  ///
  /// [fadeInDuration], [fadeInCurve], and [typingSpeed] override the preset's
  /// defaults (200ms/easeInOut fade, 80ms typing speed) when provided — leave
  /// them `null` to keep the Claude preset's tuned values.
  const StreamingTextMarkdown.claude({
    super.key,
    this.text = '',
    this.stream,
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
    this.trailingFadeEnabled = false,
    this.isLoading = false,
    this.shimmerLineCount = 3,
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
    this.selectable = false,
    this.showCursor,
    this.cursorColor,
    this.semanticsLabel,
    this.errorBuilder,
    this.completeAnimationOnTap,
    this.revealMode = RevealMode.smoothFade,
    this.pacing,
    Duration? fadeInDuration,
    Curve? fadeInCurve,
    Duration? typingSpeed,
  }) : fadeInEnabled = true,
       fadeInDuration = fadeInDuration ?? const Duration(milliseconds: 200),
       fadeInCurve = fadeInCurve ?? Curves.easeInOut,
       wordByWord = true,
       chunkSize = 1,
       typingSpeed = typingSpeed ?? const Duration(milliseconds: 80);

  /// Creates a StreamingTextMarkdown with typewriter animation
  /// Classic typewriter effect without fade-in
  ///
  /// [fadeInDuration], [fadeInCurve], and [typingSpeed] override the preset's
  /// defaults (no fade, 50ms typing speed) when provided — leave them `null`
  /// to keep the typewriter preset's tuned values.
  const StreamingTextMarkdown.typewriter({
    super.key,
    this.text = '',
    this.stream,
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
    this.trailingFadeEnabled = false,
    this.isLoading = false,
    this.shimmerLineCount = 3,
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
    this.selectable = false,
    this.showCursor,
    this.cursorColor,
    this.semanticsLabel,
    this.errorBuilder,
    this.completeAnimationOnTap,
    this.revealMode = RevealMode.typewriter,
    this.pacing,
    Duration? fadeInDuration,
    Curve? fadeInCurve,
    Duration? typingSpeed,
  }) : fadeInEnabled = false,
       fadeInDuration = fadeInDuration ?? Duration.zero,
       fadeInCurve = fadeInCurve ?? Curves.linear,
       wordByWord = false,
       chunkSize = 1,
       typingSpeed = typingSpeed ?? const Duration(milliseconds: 50);

  /// Creates a StreamingTextMarkdown with instant display
  /// For when speed is priority over animation
  ///
  /// [fadeInDuration] and [fadeInCurve] override the preset's defaults (no
  /// fade) when provided — mainly useful together with [trailingFadeEnabled],
  /// which reuses them for its dismiss animation. [typingSpeed] overrides the
  /// preset's `Duration.zero`, though `chunkSize` stays large so display
  /// remains effectively instant unless you also pass a smaller `chunkSize`.
  const StreamingTextMarkdown.instant({
    super.key,
    this.text = '',
    this.stream,
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
    this.trailingFadeEnabled = false,
    this.isLoading = false,
    this.shimmerLineCount = 3,
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
    this.selectable = false,
    this.showCursor,
    this.cursorColor,
    this.semanticsLabel,
    this.errorBuilder,
    this.completeAnimationOnTap,
    this.revealMode = RevealMode.instant,
    this.pacing,
    Duration? fadeInDuration,
    Curve? fadeInCurve,
    Duration? typingSpeed,
  }) : fadeInEnabled = false,
       fadeInDuration = fadeInDuration ?? Duration.zero,
       fadeInCurve = fadeInCurve ?? Curves.linear,
       wordByWord = false,
       chunkSize = 1000,
       typingSpeed = typingSpeed ?? Duration.zero;

  /// Creates a StreamingTextMarkdown from a preset configuration
  StreamingTextMarkdown.fromPreset({
    super.key,
    this.text = '',
    this.stream,
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
    this.trailingFadeEnabled = false,
    this.isLoading = false,
    this.shimmerLineCount = 3,
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
    this.selectable = false,
    this.showCursor,
    this.cursorColor,
    this.semanticsLabel,
    this.errorBuilder,
    this.completeAnimationOnTap,
    this.revealMode,
    this.pacing,
  }) : fadeInEnabled = preset.fadeInEnabled,
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// v1.9.1 slice 5: keeps the scroll view pinned near the bottom WHILE
  /// content is actively growing (typing or streaming), not only once at
  /// completion. Uses `jumpTo` (not `animateTo`) — an animated scroll fired
  /// on every grown chunk at typing speed would pile up competing
  /// animations. Guarded so it only jumps when there's actually more to
  /// reveal, avoiding redundant jumps when already pinned to the bottom.
  void _pinToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (_scrollController.offset < position.maxScrollExtent) {
        _scrollController.jumpTo(position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Resolved fresh on every build (not cached in didChangeDependencies)
    // so that swapping widget.theme directly — with no ancestor
    // InheritedWidget change — still restyles the output.
    final effectiveTheme = widget.theme ?? context.streamingTextTheme;

    // Resolve TextStyle with proper fallback chain
    // Priority: widget.styleSheet > theme.markdownStyleSheet > theme.markdownStyle (deprecated) > default
    final effectiveStyleSheet =
        widget.styleSheet ??
        effectiveTheme.markdownStyleSheet ??
        Theme.of(context).textTheme.bodyLarge;

    final effectivePadding =
        widget.padding ??
        effectiveTheme.defaultPadding ??
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
          key: ValueKey('streaming_text_${widget.latexEnabled}'),
          text: widget.text,
          stream: widget.stream,
          style: effectiveTheme.textStyle,
          markdownEnabled: widget.markdownEnabled,
          latexEnabled: widget.latexEnabled,
          latexStyle: widget.latexStyle ?? effectiveTheme.inlineLatexStyle,
          latexScale: widget.latexScale,
          // ignore: deprecated_member_use_from_same_package
          latexFadeInEnabled:
              // ignore: deprecated_member_use_from_same_package
              widget.latexFadeInEnabled ?? effectiveTheme.latexFadeInEnabled,
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
          trailingFadeEnabled: widget.trailingFadeEnabled,
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
          markdownOptions: widget.markdownOptions,
          selectable: widget.selectable,
          showCursor: widget.showCursor ?? (widget.stream != null),
          cursorColor: widget.cursorColor,
          semanticsLabel: widget.semanticsLabel,
          errorBuilder: widget.errorBuilder,
          completeAnimationOnTap: widget.completeAnimationOnTap ?? true,
          revealMode: widget.revealMode,
          pacing: widget.pacing,
          onTextChanged: widget.autoScroll ? _pinToBottom : null,
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
