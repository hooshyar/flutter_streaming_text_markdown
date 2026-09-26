import 'package:flutter/widgets.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'markdown_options.dart';

/// Sentinel appended to the *render* text handed to the markdown renderer to
/// mark where the caret is drawn.
///
/// Never appended to the reveal engine's source - only to the transient copy
/// built for the markdown widget while revealing, so it never affects the
/// "final text == source" / "every reveal is a prefix of source" invariants.
///
/// U+E000, the first Private Use Area code point, cannot occur in real
/// Markdown input, so it is an unambiguous marker that a normal document
/// could never contain by accident.
const String caretSentinel = '';

/// An inline pattern that matches [caretSentinel] and renders [caret] as a
/// middle-aligned widget span in its place.
///
/// Patterns are matched before the built-in Markdown components, so this
/// always wins over any (impossible) literal interpretation of the sentinel.
InlinePattern caretInlinePattern(Widget caret) {
  return InlinePattern(
    pattern: RegExp(caretSentinel),
    builder: (context, match, style) => WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: caret,
    ),
  );
}

/// Returns a copy of [options] (or a fresh bundle, when [options] is `null`)
/// with [pattern] appended to `inlinePatterns`, preserving every other field
/// - including any inline patterns the caller already supplied.
MarkdownRenderOptions withCaretPattern(
  MarkdownRenderOptions? options,
  InlinePattern pattern,
) {
  return MarkdownRenderOptions(
    styleSheet: options?.styleSheet,
    inlineCodeStyle: options?.inlineCodeStyle,
    headingBuilder: options?.headingBuilder,
    tableBuilder: options?.tableBuilder,
    blockQuoteBuilder: options?.blockQuoteBuilder,
    orderedListBuilder: options?.orderedListBuilder,
    unOrderedListBuilder: options?.unOrderedListBuilder,
    hrBuilder: options?.hrBuilder,
    checkboxBuilder: options?.checkboxBuilder,
    radioOptionBuilder: options?.radioOptionBuilder,
    onCheckboxChanged: options?.onCheckboxChanged,
    onCodeCopy: options?.onCodeCopy,
    onImageTap: options?.onImageTap,
    onSourceTagTap: options?.onSourceTagTap,
    autolink: options?.autolink,
    autolinkSchemes: options?.autolinkSchemes,
    maxLines: options?.maxLines,
    overflow: options?.overflow,
    followLinkColor: options?.followLinkColor,
    blockComponents: options?.blockComponents,
    inlinePatterns: [...?options?.inlinePatterns, pattern],
    inlineDirectives: options?.inlineDirectives,
    inlineCodeBuilder: options?.inlineCodeBuilder,
    inlineLinkBuilder: options?.inlineLinkBuilder,
    inlineSourceTagBuilder: options?.inlineSourceTagBuilder,
    imageBuilder: options?.imageBuilder,
    useDollarSignsForLatex: options?.useDollarSignsForLatex,
  );
}
