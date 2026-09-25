import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// Bundles the `gpt_markdown` 1.3 pass-throughs that don't already have a
/// dedicated [StreamingText]/[StreamingTextMarkdown] parameter.
///
/// Every field here maps 1:1 onto a `GptMarkdown` constructor parameter of
/// the same name (see `package:gpt_markdown/gpt_markdown.dart`). A `null`
/// field is simply omitted when building the underlying `GptMarkdown`, so
/// nothing here changes `gpt_markdown`'s own defaults unless set.
///
/// This is the single place new `gpt_markdown` forwards land, rather than
/// adding another top-level constructor parameter per release.
@immutable
class MarkdownRenderOptions {
  /// Creates a bundle of `gpt_markdown` pass-through options.
  const MarkdownRenderOptions({
    this.styleSheet,
    this.inlineCodeStyle,
    this.headingBuilder,
    this.tableBuilder,
    this.blockQuoteBuilder,
    this.orderedListBuilder,
    this.unOrderedListBuilder,
    this.hrBuilder,
    this.checkboxBuilder,
    this.radioOptionBuilder,
    this.onCheckboxChanged,
    this.onCodeCopy,
    this.onImageTap,
    this.onSourceTagTap,
    this.autolink,
    this.autolinkSchemes,
    this.maxLines,
    this.overflow,
    this.followLinkColor,
    this.blockComponents,
    this.inlinePatterns,
    this.inlineDirectives,
    this.inlineCodeBuilder,
    this.inlineLinkBuilder,
    this.inlineSourceTagBuilder,
    this.imageBuilder,
    this.useDollarSignsForLatex,
  });

  /// Forwarded to `GptMarkdown.styleSheet`.
  final GptMarkdownStyleSheet? styleSheet;

  /// Forwarded to `GptMarkdown.inlineCodeStyle`.
  final InlineCodeStyle? inlineCodeStyle;

  /// Forwarded to `GptMarkdown.headingBuilder`.
  final HeadingBuilder? headingBuilder;

  /// Forwarded to `GptMarkdown.tableBuilder`.
  final TableBuilder? tableBuilder;

  /// Forwarded to `GptMarkdown.blockQuoteBuilder`.
  final BlockQuoteBuilder? blockQuoteBuilder;

  /// Forwarded to `GptMarkdown.orderedListBuilder`.
  final OrderedListBuilder? orderedListBuilder;

  /// Forwarded to `GptMarkdown.unOrderedListBuilder`.
  final UnOrderedListBuilder? unOrderedListBuilder;

  /// Forwarded to `GptMarkdown.hrBuilder`.
  final HrBuilder? hrBuilder;

  /// Forwarded to `GptMarkdown.checkboxBuilder`.
  final CheckboxBuilder? checkboxBuilder;

  /// Forwarded to `GptMarkdown.radioOptionBuilder`.
  final RadioOptionBuilder? radioOptionBuilder;

  /// Forwarded to `GptMarkdown.onCheckboxChanged`.
  final void Function(bool value)? onCheckboxChanged;

  /// Forwarded to `GptMarkdown.onCodeCopy`.
  final void Function(String code)? onCodeCopy;

  /// Forwarded to `GptMarkdown.onImageTap`.
  final void Function(String url)? onImageTap;

  /// Forwarded to `GptMarkdown.onSourceTagTap`.
  final void Function(String content)? onSourceTagTap;

  /// Forwarded to `GptMarkdown.autolink`. `null` keeps `gpt_markdown`'s own
  /// default (`true`).
  final bool? autolink;

  /// Forwarded to `GptMarkdown.autolinkSchemes`.
  final Set<String>? autolinkSchemes;

  /// Forwarded to `GptMarkdown.maxLines`.
  final int? maxLines;

  /// Forwarded to `GptMarkdown.overflow`.
  final TextOverflow? overflow;

  /// Forwarded to `GptMarkdown.followLinkColor`. `null` keeps `gpt_markdown`'s
  /// own default (`false`).
  final bool? followLinkColor;

  /// Forwarded to `GptMarkdown.blockComponents`.
  final List<MarkdownBlockComponent>? blockComponents;

  /// Forwarded to `GptMarkdown.inlinePatterns`.
  final List<InlinePattern>? inlinePatterns;

  /// Forwarded to `GptMarkdown.inlineDirectives`.
  final List<InlineDirective>? inlineDirectives;

  /// Forwarded to `GptMarkdown.inlineCodeBuilder`.
  final InlineCodeBuilder? inlineCodeBuilder;

  /// Forwarded to `GptMarkdown.inlineLinkBuilder`.
  final InlineLinkBuilder? inlineLinkBuilder;

  /// Forwarded to `GptMarkdown.inlineSourceTagBuilder`.
  final InlineSourceTagBuilder? inlineSourceTagBuilder;

  /// Forwarded to `GptMarkdown.imageBuilder`. Unlike the legacy
  /// [StreamingText.imageBuilder]/[StreamingTextMarkdown.imageBuilder]
  /// (`(context, url)`), this carries `gpt_markdown`'s full signature,
  /// including the `WxH` size parsed from the image's alt text.
  final ImageBuilder? imageBuilder;

  /// Forwarded to `GptMarkdown.useDollarSignsForLatex`. When `null`, the
  /// renderer falls back to the widget's `latexEnabled` value.
  final bool? useDollarSignsForLatex;
}
