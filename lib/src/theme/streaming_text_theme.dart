import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'dart:ui' show lerpDouble;

/// Theme extension for StreamingTextMarkdown widget
class StreamingTextTheme extends ThemeExtension<StreamingTextTheme> {
  /// The style for normal text
  final TextStyle? textStyle;

  /// The style for markdown content
  final MarkdownStyleSheet? markdownStyleSheet;

  /// The default padding for the widget
  final EdgeInsets? defaultPadding;

  /// Creates a [StreamingTextTheme]
  const StreamingTextTheme({
    this.textStyle,
    this.markdownStyleSheet,
    this.defaultPadding,
  });

  /// Creates a default theme with basic styling
  factory StreamingTextTheme.defaults(BuildContext context) {
    final theme = Theme.of(context);
    return StreamingTextTheme(
      textStyle: theme.textTheme.bodyLarge,
      markdownStyleSheet: MarkdownStyleSheet.fromTheme(theme),
      defaultPadding: const EdgeInsets.all(16.0),
    );
  }

  /// Custom lerp method for MarkdownStyleSheet
  static MarkdownStyleSheet? _lerpMarkdownStyleSheet(
    MarkdownStyleSheet? a,
    MarkdownStyleSheet? b,
    double t,
  ) {
    if (a == null && b == null) return null;
    if (a == null) return b;
    if (b == null) return a;

    return MarkdownStyleSheet(
      a: TextStyle.lerp(a.a, b.a, t),
      p: TextStyle.lerp(a.p, b.p, t),
      code: TextStyle.lerp(a.code, b.code, t),
      h1: TextStyle.lerp(a.h1, b.h1, t),
      h2: TextStyle.lerp(a.h2, b.h2, t),
      h3: TextStyle.lerp(a.h3, b.h3, t),
      h4: TextStyle.lerp(a.h4, b.h4, t),
      h5: TextStyle.lerp(a.h5, b.h5, t),
      h6: TextStyle.lerp(a.h6, b.h6, t),
      em: TextStyle.lerp(a.em, b.em, t),
      strong: TextStyle.lerp(a.strong, b.strong, t),
      blockquote: TextStyle.lerp(a.blockquote, b.blockquote, t),
      img: TextStyle.lerp(a.img, b.img, t),
      blockSpacing: t < 0.5 ? a.blockSpacing : b.blockSpacing,
      listIndent: lerpDouble(a.listIndent, b.listIndent, t),
      blockquotePadding: t < 0.5 ? a.blockquotePadding : b.blockquotePadding,
      blockquoteDecoration:
          Decoration.lerp(a.blockquoteDecoration, b.blockquoteDecoration, t),
      codeblockPadding: t < 0.5 ? a.codeblockPadding : b.codeblockPadding,
      codeblockDecoration:
          Decoration.lerp(a.codeblockDecoration, b.codeblockDecoration, t),
      horizontalRuleDecoration: Decoration.lerp(
          a.horizontalRuleDecoration, b.horizontalRuleDecoration, t),
    );
  }

  @override
  StreamingTextTheme copyWith({
    TextStyle? textStyle,
    MarkdownStyleSheet? markdownStyleSheet,
    EdgeInsets? defaultPadding,
  }) {
    return StreamingTextTheme(
      textStyle: textStyle ?? this.textStyle,
      markdownStyleSheet: markdownStyleSheet ?? this.markdownStyleSheet,
      defaultPadding: defaultPadding ?? this.defaultPadding,
    );
  }

  @override
  StreamingTextTheme lerp(ThemeExtension<StreamingTextTheme>? other, double t) {
    if (other is! StreamingTextTheme) {
      return this;
    }

    return StreamingTextTheme(
      textStyle: TextStyle.lerp(textStyle, other.textStyle, t),
      markdownStyleSheet: _lerpMarkdownStyleSheet(
          markdownStyleSheet, other.markdownStyleSheet, t),
      defaultPadding: EdgeInsets.lerp(defaultPadding, other.defaultPadding, t),
    );
  }
}

/// Extension method to easily access StreamingTextTheme from BuildContext
extension StreamingTextThemeExtension on BuildContext {
  /// Get the current StreamingTextTheme
  StreamingTextTheme get streamingTextTheme {
    return Theme.of(this).extension<StreamingTextTheme>() ??
        StreamingTextTheme.defaults(this);
  }
}
