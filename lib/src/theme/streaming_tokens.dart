import 'dart:ui' show Brightness, Color;

/// Neutral-ramp design tokens for streaming text rendering.
///
/// Values come from DESIGN.md section 3. Tokens resolve from [Brightness]
/// only, never from `colorScheme.surface*`. Internal to the package.
class StreamingTokens {
  /// Creates a token set. Prefer [StreamingTokens.of].
  const StreamingTokens({
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.borderStrong,
    required this.surfaceSunken,
    required this.inlineCodeBg,
    required this.danger,
  });

  /// Resolves the token set for [brightness].
  factory StreamingTokens.of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// Light-theme tokens.
  static const StreamingTokens light = StreamingTokens(
    textPrimary: Color(0xFF18181B),
    textSecondary: Color(0xFF52525B),
    textTertiary: Color(0xFF6B6B73),
    border: Color(0xFFE4E4E2),
    borderStrong: Color(0xFF85858D),
    surfaceSunken: Color(0xFFF3F3F1),
    inlineCodeBg: Color(0xFFEEEEEB),
    danger: Color(0xFFC4321C),
  );

  /// Dark-theme tokens.
  static const StreamingTokens dark = StreamingTokens(
    textPrimary: Color(0xFFEDEDEF),
    textSecondary: Color(0xFFA8A8B0),
    textTertiary: Color(0xFF8C8C94),
    border: Color(0xFF2A2A2F),
    borderStrong: Color(0xFF6A6A72),
    surfaceSunken: Color(0xFF1C1C1F),
    inlineCodeBg: Color(0xFF232327),
    danger: Color(0xFFFF7A66),
  );

  /// Body, headings, math and caret colour.
  final Color textPrimary;

  /// Blockquote text, list bullets.
  final Color textSecondary;

  /// Code language labels, held-back math source and table captions.
  final Color textTertiary;

  /// Table hairlines, `hr`, code border, blockquote rule (light).
  final Color border;

  /// Blockquote rule (dark).
  final Color borderStrong;

  /// Table header row fill.
  final Color surfaceSunken;

  /// Inline `code` chip fill.
  final Color inlineCodeBg;

  /// Error and malformed-input accents. Replaces `Colors.red`.
  final Color danger;
}
