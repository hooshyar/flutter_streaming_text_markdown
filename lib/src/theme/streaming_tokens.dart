import 'dart:ui' show Brightness, Color;

/// Neutral-ramp design tokens for streaming text rendering.
///
/// Values come from DESIGN.md section 3. Tokens resolve from [Brightness]
/// only, never from `colorScheme.surface*`. Internal to the package.
class StreamingTokens {
  /// Creates a token set. Prefer [StreamingTokens.of].
  const StreamingTokens({
    required this.textPrimary,
    required this.textTertiary,
    required this.danger,
  });

  /// Resolves the token set for [brightness].
  factory StreamingTokens.of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// Light-theme tokens.
  static const StreamingTokens light = StreamingTokens(
    textPrimary: Color(0xFF18181B),
    textTertiary: Color(0xFF6B6B73),
    danger: Color(0xFFC4321C),
  );

  /// Dark-theme tokens.
  static const StreamingTokens dark = StreamingTokens(
    textPrimary: Color(0xFFEDEDEF),
    textTertiary: Color(0xFF8C8C94),
    danger: Color(0xFFFF7A66),
  );

  /// Body, headings, math and caret colour.
  final Color textPrimary;

  /// Code language labels, held-back math source and table captions.
  final Color textTertiary;

  /// Error and malformed-input accents. Replaces `Colors.red`.
  final Color danger;
}
