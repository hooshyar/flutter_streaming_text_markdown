import 'package:flutter/material.dart';
import 'dart:ui' show lerpDouble;

/// Theme extension for StreamingTextMarkdown widget
class StreamingTextTheme extends ThemeExtension<StreamingTextTheme> {
  /// The style for normal text
  final TextStyle? textStyle;

  /// The style for markdown content
  final TextStyle? markdownStyle;

  /// The default padding for the widget
  final EdgeInsets? defaultPadding;

  /// The style for inline LaTeX expressions
  final TextStyle? inlineLatexStyle;

  /// The style for block LaTeX expressions
  final TextStyle? blockLatexStyle;

  /// Scale factor for LaTeX equations (default: 1.0)
  final double? latexScale;

  /// Whether to enable fade-in animations for LaTeX content
  final bool? latexFadeInEnabled;

  /// Creates a [StreamingTextTheme]
  const StreamingTextTheme({
    this.textStyle,
    this.markdownStyle,
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
      markdownStyle: baseTextStyle,
      defaultPadding: const EdgeInsets.all(16.0),
      inlineLatexStyle: baseTextStyle?.copyWith(
        fontSize: (baseTextStyle.fontSize ?? 14) * 1.1,
        fontWeight: FontWeight.w500,
      ),
      blockLatexStyle: baseTextStyle?.copyWith(
        fontSize: (baseTextStyle.fontSize ?? 14) * 1.2,
        fontWeight: FontWeight.w500,
      ),
      latexScale: 1.0,
      latexFadeInEnabled: false, // Disabled by default for performance
    );
  }

  @override
  StreamingTextTheme copyWith({
    TextStyle? textStyle,
    TextStyle? markdownStyle,
    EdgeInsets? defaultPadding,
    TextStyle? inlineLatexStyle,
    TextStyle? blockLatexStyle,
    double? latexScale,
    bool? latexFadeInEnabled,
  }) {
    return StreamingTextTheme(
      textStyle: textStyle ?? this.textStyle,
      markdownStyle: markdownStyle ?? this.markdownStyle,
      defaultPadding: defaultPadding ?? this.defaultPadding,
      inlineLatexStyle: inlineLatexStyle ?? this.inlineLatexStyle,
      blockLatexStyle: blockLatexStyle ?? this.blockLatexStyle,
      latexScale: latexScale ?? this.latexScale,
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
      markdownStyle: TextStyle.lerp(markdownStyle, other.markdownStyle, t),
      defaultPadding: EdgeInsets.lerp(defaultPadding, other.defaultPadding, t),
      inlineLatexStyle:
          TextStyle.lerp(inlineLatexStyle, other.inlineLatexStyle, t),
      blockLatexStyle:
          TextStyle.lerp(blockLatexStyle, other.blockLatexStyle, t),
      latexScale: lerpDouble(latexScale, other.latexScale, t),
      latexFadeInEnabled:
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
