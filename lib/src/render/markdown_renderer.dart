import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../engine/atomic_spans.dart';
import 'markdown_options.dart';
import 'mend.dart';

/// The single place a `GptMarkdown` widget is built.
///
/// A stateless adapter between [StreamingText]'s legacy, individually-named
/// markdown parameters (kept for backward compatibility) and `gpt_markdown`
/// 1.3's builder surface, plus the newer [MarkdownRenderOptions] bundle.
///
/// Resolution order for anything with both a legacy top-level parameter and
/// an [options] field: **the legacy builder wins when non-null**; otherwise
/// the [options] field (if any) is used. This keeps every pre-1.11 caller's
/// behaviour identical while giving new pass-throughs a home that doesn't
/// grow with every `gpt_markdown` release.
class StreamingMarkdownView extends StatelessWidget {
  /// Creates a streaming markdown view.
  const StreamingMarkdownView({
    super.key,
    required this.text,
    required this.isComplete,
    this.isStreaming = false,
    this.style,
    this.textDirection,
    this.textAlign,
    this.textScaler,
    this.latexEnabled = false,
    this.latexStyle,
    this.latexScale = 1.0,
    this.options,
    this.imageBuilder,
    this.onLinkTap,
    this.codeBuilder,
    this.latexBuilder,
    this.sourceTagBuilder,
    this.highlightBuilder,
    this.linkBuilder,
    this.components,
    this.inlineComponents,
    this.revealFadeEnabled = false,
    this.revealFadeSeconds = 0.18,
  });

  /// The full (unmended) source text. [mend] is applied internally before
  /// this reaches `GptMarkdown`.
  final String text;

  /// Whether the reveal is finished. Forwarded to [mend] and to
  /// `GptMarkdown.isStreaming` (inverted).
  final bool isComplete;

  /// Forwarded to `GptMarkdown.isStreaming`.
  final bool isStreaming;

  /// The B1-S5 hybrid (PHASE-B1-PLAN.md, acceptance criterion 9/11): when
  /// `true`, [text] (already the head our own [RevealEngine] has revealed)
  /// is handed to `GptMarkdown` with `animation: GptMarkdownAnimation.fade`
  /// and a deliberately huge `charactersPerSecond`, so `gpt_markdown`'s own
  /// pacing head never lags our cursor — it only softens the paint of
  /// whatever we already decided is revealed. Our engine still owns
  /// pacing, lifecycle and the caret either way.
  ///
  /// `false` (the default) builds exactly the pre-B1-S5 tree:
  /// `GptMarkdownAnimation.none`, no fade.
  final bool revealFadeEnabled;

  /// Forwarded to `GptMarkdown.revealFadeSeconds` when [revealFadeEnabled]
  /// is `true`. Ignored otherwise.
  final double revealFadeSeconds;

  /// Forwarded to `GptMarkdown.style`.
  final TextStyle? style;

  /// Forwarded to `GptMarkdown.textDirection`. Callers should resolve
  /// auto-detected RTL direction before passing this in — this widget does
  /// not sniff the text itself.
  final TextDirection? textDirection;

  /// Forwarded to `GptMarkdown.textAlign`.
  final TextAlign? textAlign;

  /// Forwarded to `GptMarkdown.textScaler`.
  final TextScaler? textScaler;

  /// Whether `$...$` / `$$...$$` LaTeX is recognized at all. When
  /// [MarkdownRenderOptions.useDollarSignsForLatex] is left `null`, this
  /// widget rewrites those delimiters to `gpt_markdown`'s native
  /// `\(...\)` / `\[...\]` syntax itself (see [AtomicSpanDetector.
  /// rewriteDollarDelimiters]) instead of forwarding
  /// `useDollarSignsForLatex` to `gpt_markdown` - its own rewrite runs
  /// before it knows what is code, so `$VARS` inside a fenced shell block
  /// gets mangled into a LaTeX delimiter (W11).
  final bool latexEnabled;

  /// Text style applied to the default LaTeX fallback builder installed when
  /// [latexBuilder] is null and either this or [latexScale] is customized.
  final TextStyle? latexStyle;

  /// Scale factor applied to the default LaTeX fallback builder's font size.
  final double latexScale;

  /// New `gpt_markdown` 1.3 pass-throughs that don't have a legacy top-level
  /// parameter of their own.
  final MarkdownRenderOptions? options;

  /// Legacy image builder, `(context, imageUrl)`. Wins over
  /// [MarkdownRenderOptions.imageBuilder] when non-null.
  final Widget Function(BuildContext context, String imageUrl)? imageBuilder;

  /// Forwarded to `GptMarkdown.onLinkTap`.
  final void Function(String url, String title)? onLinkTap;

  /// Forwarded to `GptMarkdown.codeBuilder`.
  final Widget Function(
    BuildContext context,
    String name,
    String code,
    bool closed,
  )?
  codeBuilder;

  /// Legacy LaTeX builder. Wins over the default fallback builder installed
  /// from [latexStyle]/[latexScale] when non-null.
  final Widget Function(
    BuildContext context,
    String tex,
    TextStyle textStyle,
    bool inline,
  )?
  latexBuilder;

  /// Legacy source-tag builder. Wins over
  /// [MarkdownRenderOptions.inlineSourceTagBuilder] when non-null.
  final Widget Function(
    BuildContext context,
    String content,
    TextStyle textStyle,
  )?
  sourceTagBuilder;

  /// Legacy inline-code builder. Wins over
  /// [MarkdownRenderOptions.inlineCodeBuilder] when non-null.
  final Widget Function(BuildContext context, String text, TextStyle style)?
  highlightBuilder;

  /// Legacy link builder. Wins over
  /// [MarkdownRenderOptions.inlineLinkBuilder] when non-null.
  final Widget Function(
    BuildContext context,
    InlineSpan text,
    String url,
    TextStyle style,
  )?
  linkBuilder;

  /// Forwarded to `GptMarkdown.components` (deprecated in `gpt_markdown`
  /// itself) only when non-null — passing it at all, even empty, switches
  /// `gpt_markdown` onto its legacy regex pipeline and disables the segment
  /// cache.
  final List<MarkdownComponent>? components;

  /// Forwarded to `GptMarkdown.inlineComponents` (deprecated in
  /// `gpt_markdown` itself) only when non-null, for the same reason as
  /// [components].
  final List<MarkdownComponent>? inlineComponents;

  /// The default LaTeX builder installed when the caller customized
  /// [latexStyle]/[latexScale] but didn't supply their own [latexBuilder].
  Widget _defaultLatexBuilder(
    BuildContext context,
    String tex,
    TextStyle textStyle,
    bool inline,
  ) {
    final mergedStyle = textStyle.merge(latexStyle);
    final fontSize = (mergedStyle.fontSize ?? 16) * latexScale;
    final resolvedStyle = mergedStyle.copyWith(fontSize: fontSize);
    return Math.tex(
      tex,
      mathStyle: inline ? MathStyle.text : MathStyle.display,
      textStyle: resolvedStyle,
      onErrorFallback:
          (error) => Text(
            tex,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: fontSize,
              color: resolvedStyle.color,
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final opts = options;
    final withheldText = mend(text, isComplete: isComplete);
    // Only forward `useDollarSignsForLatex` to gpt_markdown when the caller
    // set it explicitly - that opts into gpt_markdown's own naive, code-
    // oblivious `$...$` rewrite on purpose. Otherwise, when latexEnabled is
    // on, do the rewrite ourselves (code-aware, currency-safe) and let
    // gpt_markdown parse the resulting `\(...\)`/`\[...\]` natively.
    final explicitUseDollarSigns = opts?.useDollarSignsForLatex;
    final renderText =
        explicitUseDollarSigns == null && latexEnabled
            ? const AtomicSpanDetector().rewriteDollarDelimiters(withheldText)
            : withheldText;

    final effectiveImageBuilder =
        imageBuilder != null
            ? (BuildContext ctx, String url, double? width, double? height) =>
                imageBuilder!(ctx, url)
            : opts?.imageBuilder;

    final effectiveLatexBuilder =
        latexBuilder ??
        (latexStyle != null || latexScale != 1.0 ? _defaultLatexBuilder : null);

    final effectiveSourceTagBuilder =
        sourceTagBuilder != null
            ? (SourceTagBuildDetails d) =>
                d.asWidgetSpan(sourceTagBuilder!(context, d.id, d.style))
            : opts?.inlineSourceTagBuilder;

    final effectiveInlineCodeBuilder =
        highlightBuilder != null
            ? (
              BuildContext ctx,
              String code,
              TextStyle style,
              InlineCodeStyle codeStyle,
            ) => baselineWidgetSpan(highlightBuilder!(ctx, code, style))
            : opts?.inlineCodeBuilder;

    final effectiveLinkBuilder =
        linkBuilder != null
            ? (LinkBuildDetails d) => d.asWidgetSpan(
              linkBuilder!(
                context,
                TextSpan(children: d.labelSpans),
                d.url,
                d.style,
              ),
            )
            : opts?.inlineLinkBuilder;

    return GptMarkdown(
      renderText,
      style: style,
      textDirection: textDirection ?? TextDirection.ltr,
      textAlign: textAlign,
      textScaler: textScaler,
      isStreaming: isStreaming,
      animation:
          revealFadeEnabled
              ? GptMarkdownAnimation.fade
              : GptMarkdownAnimation.none,
      // Huge on purpose (see [revealFadeEnabled]'s doc): our own engine
      // already decided what is revealed - gpt_markdown's head must never
      // lag behind that cursor, it only softens the paint.
      charactersPerSecond: revealFadeEnabled ? 1000000 : 300,
      revealFadeSeconds: revealFadeSeconds,
      useDollarSignsForLatex: explicitUseDollarSigns ?? false,
      imageBuilder: effectiveImageBuilder,
      onLinkTap: onLinkTap,
      codeBuilder: codeBuilder,
      latexBuilder: effectiveLatexBuilder,
      inlineSourceTagBuilder: effectiveSourceTagBuilder,
      inlineCodeBuilder: effectiveInlineCodeBuilder,
      inlineLinkBuilder: effectiveLinkBuilder,
      // Only ever non-null when the user supplied them directly — see the
      // field docs above for why gpt_markdown treats any non-null value
      // (even an empty list) as opting into its legacy pipeline.
      // ignore: deprecated_member_use
      components: components,
      // ignore: deprecated_member_use
      inlineComponents: inlineComponents,
      styleSheet: opts?.styleSheet,
      inlineCodeStyle: opts?.inlineCodeStyle,
      headingBuilder: opts?.headingBuilder,
      tableBuilder: opts?.tableBuilder,
      blockQuoteBuilder: opts?.blockQuoteBuilder,
      orderedListBuilder: opts?.orderedListBuilder,
      unOrderedListBuilder: opts?.unOrderedListBuilder,
      hrBuilder: opts?.hrBuilder,
      checkboxBuilder: opts?.checkboxBuilder,
      radioOptionBuilder: opts?.radioOptionBuilder,
      onCheckboxChanged: opts?.onCheckboxChanged,
      onCodeCopy: opts?.onCodeCopy,
      onImageTap: opts?.onImageTap,
      onSourceTagTap: opts?.onSourceTagTap,
      autolink: opts?.autolink ?? true,
      autolinkSchemes: opts?.autolinkSchemes ?? const <String>{},
      maxLines: opts?.maxLines,
      overflow: opts?.overflow,
      followLinkColor: opts?.followLinkColor ?? false,
      blockComponents: opts?.blockComponents,
      inlinePatterns: opts?.inlinePatterns,
      inlineDirectives: opts?.inlineDirectives,
    );
  }
}
