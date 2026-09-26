import 'package:flutter/material.dart';
import 'dart:ui' show lerpDouble;

/// Theme extension for StreamingTextMarkdown widget
class StreamingTextTheme extends ThemeExtension<StreamingTextTheme> {
  /// The style for normal text
  final TextStyle? textStyle;

  /// The style for markdown content
  ///
  /// DEPRECATED: Use [markdownStyleSheet] instead for granular control over
  /// different markdown elements (h1, h2, p, etc.). This property is kept for
  /// backward compatibility and will be removed in v2.0.0.
  @Deprecated('Use markdownStyleSheet instead. Will be removed in v2.0.0')
  final TextStyle? markdownStyle;

  /// Style for markdown elements
  ///
  /// TextStyle applied to the GptMarkdown renderer. If not provided,
  /// defaults will be derived from the theme's text styles.
  final TextStyle? markdownStyleSheet;

  /// The default padding for the widget
  final EdgeInsets? defaultPadding;

  /// The style for inline LaTeX expressions
  final TextStyle? inlineLatexStyle;

  /// The style for block LaTeX expressions.
  @Deprecated(
    'No-op. LaTeX rendering is delegated to gpt_markdown; use a '
    'StreamingText/StreamingTextMarkdown latexBuilder to style block LaTeX '
    'directly. Will be removed in 2.0.0.',
  )
  final TextStyle? blockLatexStyle;

  /// Scale factor for LaTeX equations (default: 1.0).
  @Deprecated(
    'No-op at the theme level. Use the widget-level latexScale parameter '
    'on StreamingText/StreamingTextMarkdown instead. Will be removed in '
    '2.0.0.',
  )
  final double? latexScale;

  /// Whether to enable fade-in animations for LaTeX content.
  @Deprecated(
    'No-op. LaTeX rendering is delegated to gpt_markdown, which has no '
    'per-run fade hook of its own; use latexBuilder to control LaTeX '
    'rendering directly. Will be removed in 2.0.0.',
  )
  final bool? latexFadeInEnabled;

  /// Creates a [StreamingTextTheme]
  const StreamingTextTheme({
    this.textStyle,
    @Deprecated('Use markdownStyleSheet instead') this.markdownStyle,
    this.markdownStyleSheet,
    this.defaultPadding,
    this.inlineLatexStyle,
    this.blockLatexStyle,
    this.latexScale,
    this.latexFadeInEnabled,
  });

  /// Creates a default theme with basic styling
  factory StreamingTextTheme.defaults(BuildContext context) {
    final theme = Theme.of(context);
    final baseTextStyle = theme.textTheme.bodyLarge;

    return StreamingTextTheme(
      textStyle: baseTextStyle,
      markdownStyleSheet: baseTextStyle,
      defaultPadding: const EdgeInsets.all(16.0),
      inlineLatexStyle: baseTextStyle?.copyWith(
        fontSize: (baseTextStyle.fontSize ?? 14) * 1.1,
        fontWeight: FontWeight.w500,
      ),
      // ignore: deprecated_member_use_from_same_package
      blockLatexStyle: baseTextStyle?.copyWith(
        fontSize: (baseTextStyle.fontSize ?? 14) * 1.2,
        fontWeight: FontWeight.w500,
      ),
      // ignore: deprecated_member_use_from_same_package
      latexScale: 1.0,
      // ignore: deprecated_member_use_from_same_package
      latexFadeInEnabled: false, // Disabled by default for performance
    );
  }

  @override
  StreamingTextTheme copyWith({
    TextStyle? textStyle,
    @Deprecated('Use markdownStyleSheet instead') TextStyle? markdownStyle,
    TextStyle? markdownStyleSheet,
    EdgeInsets? defaultPadding,
    TextStyle? inlineLatexStyle,
    TextStyle? blockLatexStyle,
    double? latexScale,
    bool? latexFadeInEnabled,
  }) {
    return StreamingTextTheme(
      textStyle: textStyle ?? this.textStyle,
      // ignore: deprecated_member_use_from_same_package
      markdownStyle: markdownStyle ?? this.markdownStyle,
      // ignore: deprecated_member_use_from_same_package
      markdownStyleSheet:
          markdownStyleSheet ??
          this.markdownStyleSheet ??
          (markdownStyle ?? this.markdownStyle),
      defaultPadding: defaultPadding ?? this.defaultPadding,
      inlineLatexStyle: inlineLatexStyle ?? this.inlineLatexStyle,
      // ignore: deprecated_member_use_from_same_package
      blockLatexStyle: blockLatexStyle ?? this.blockLatexStyle,
      // ignore: deprecated_member_use_from_same_package
      latexScale: latexScale ?? this.latexScale,
      // ignore: deprecated_member_use_from_same_package
      latexFadeInEnabled: latexFadeInEnabled ?? this.latexFadeInEnabled,
    );
  }

  @override
  StreamingTextTheme lerp(ThemeExtension<StreamingTextTheme>? other, double t) {
    if (other is! StreamingTextTheme) {
      return this;
    }

    return StreamingTextTheme(
      textStyle: TextStyle.lerp(textStyle, other.textStyle, t),
      // ignore: deprecated_member_use_from_same_package
      markdownStyle: TextStyle.lerp(markdownStyle, other.markdownStyle, t),
      markdownStyleSheet: TextStyle.lerp(
        markdownStyleSheet,
        other.markdownStyleSheet,
        t,
      ),
      defaultPadding: EdgeInsets.lerp(defaultPadding, other.defaultPadding, t),
      inlineLatexStyle: TextStyle.lerp(
        inlineLatexStyle,
        other.inlineLatexStyle,
        t,
      ),
      // ignore: deprecated_member_use_from_same_package
      blockLatexStyle:
      // ignore: deprecated_member_use_from_same_package
      TextStyle.lerp(blockLatexStyle, other.blockLatexStyle, t),
      // ignore: deprecated_member_use_from_same_package
      latexScale: lerpDouble(latexScale, other.latexScale, t),
      // ignore: deprecated_member_use_from_same_package
      latexFadeInEnabled:
          // ignore: deprecated_member_use_from_same_package
          t < 0.5 ? latexFadeInEnabled : other.latexFadeInEnabled,
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
