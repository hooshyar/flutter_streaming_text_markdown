/// Types of text segments
enum SegmentType {
  regular,
  inlineLaTeX,
  blockLaTeX,
}

/// Represents a segment of text that may be regular text or LaTeX
class TextSegment {
  final String content;
  final SegmentType type;
  final int startIndex;
  final int endIndex;

  const TextSegment({
    required this.content,
    required this.type,
    required this.startIndex,
    required this.endIndex,
  });

  /// Whether this segment contains LaTeX content
  bool get isLaTeX => type != SegmentType.regular;

  /// The length of the content
  int get length => content.length;

  /// The full LaTeX expression including delimiters
  String get fullExpression {
    switch (type) {
      case SegmentType.inlineLaTeX:
        return '\$$content\$';
      case SegmentType.blockLaTeX:
        return '\$\$$content\$\$';
      case SegmentType.regular:
        return content;
    }
  }
}

/// Utility class for processing LaTeX content within text.
///
/// This class provides methods to detect, parse, and handle LaTeX expressions
/// in text that may contain both regular content and mathematical formulas.
class LaTeXProcessor {
  /// Regular expression for inline LaTeX expressions (single dollar signs with content, not standalone numbers/prices)
  static final RegExp _inlineLatexPattern = RegExp(
      r'(?<!\$)\$([^\$\s][^\$]*[^\$\s]|[a-zA-Z=+\-*/\\^_{}()]+)\$(?!\$)');

  /// Regular expression for block LaTeX expressions (double dollar signs)
  static final RegExp _blockLatexPattern = RegExp(r'\$\$([^\$]+)\$\$');

  /// Combined pattern for any LaTeX content (prioritizes block over inline)
  static final RegExp _anyLatexPattern = RegExp(
      r'\$\$[^\$]+\$\$|(?<!\$)\$([^\$\s][^\$]*[^\$\s]|[a-zA-Z=+\-*/\\^_{}()]+)\$(?!\$)');

  /// Checks if the given text contains any LaTeX expressions
  static bool containsLaTeX(String text) {
    return _anyLatexPattern.hasMatch(text);
  }

  /// Checks if the given text contains inline LaTeX expressions
  static bool containsInlineLaTeX(String text) {
    return _inlineLatexPattern.hasMatch(text);
  }

  /// Checks if the given text contains block LaTeX expressions
  static bool containsBlockLaTeX(String text) {
    return _blockLatexPattern.hasMatch(text);
  }

  /// Parses text into segments, separating regular text from LaTeX expressions
  static List<TextSegment> parseTextSegments(String text) {
    final segments = <TextSegment>[];

    if (text.isEmpty) return segments;

    // Create a list of all LaTeX matches with their positions
    final List<_LaTeXMatch> matches = [];

    // Find all block LaTeX expressions first (to prioritize them over inline)
    for (final match in _blockLatexPattern.allMatches(text)) {
      matches.add(_LaTeXMatch(
        start: match.start,
        end: match.end,
        content: match.group(1)!,
        type: SegmentType.blockLaTeX,
      ));
    }

    // Find all inline LaTeX expressions
    for (final match in _inlineLatexPattern.allMatches(text)) {
      // Skip if this match overlaps with a block match
      bool overlaps = matches.any((m) =>
          (match.start >= m.start && match.start < m.end) ||
          (match.end > m.start && match.end <= m.end));

      if (!overlaps) {
        matches.add(_LaTeXMatch(
          start: match.start,
          end: match.end,
          content: match.group(1)!,
          type: SegmentType.inlineLaTeX,
        ));
      }
    }

    // Sort matches by position
    matches.sort((a, b) => a.start.compareTo(b.start));

    // Build segments
    int currentIndex = 0;

    for (final match in matches) {
      // Add regular text before this LaTeX expression
      if (currentIndex < match.start) {
        segments.add(TextSegment(
          content: text.substring(currentIndex, match.start),
          type: SegmentType.regular,
          startIndex: currentIndex,
          endIndex: match.start,
        ));
      }

      // Add the LaTeX expression
      segments.add(TextSegment(
        content: match.content,
        type: match.type,
        startIndex: match.start,
        endIndex: match.end,
      ));

      currentIndex = match.end;
    }

    // Add any remaining regular text
    if (currentIndex < text.length) {
      segments.add(TextSegment(
        content: text.substring(currentIndex),
        type: SegmentType.regular,
        startIndex: currentIndex,
        endIndex: text.length,
      ));
    }

    return segments;
  }

  /// Gets the indices of all LaTeX expressions in the text
  static List<(int start, int end)> getLatexIndices(String text) {
    final indices = <(int, int)>[];

    // Get all LaTeX matches
    for (final match in _anyLatexPattern.allMatches(text)) {
      indices.add((match.start, match.end));
    }

    return indices;
  }

  /// Checks if a given position in the text is within a LaTeX expression
  static bool isPositionInLatex(String text, int position) {
    final indices = getLatexIndices(text);

    for (final (start, end) in indices) {
      if (position >= start && position < end) {
        return true;
      }
    }

    return false;
  }

  /// Counts the number of LaTeX expressions in the text
  static int countLatexExpressions(String text) {
    return _anyLatexPattern.allMatches(text).length;
  }

  /// Extracts all LaTeX expressions from the text
  static List<String> extractLatexExpressions(String text) {
    final expressions = <String>[];

    for (final match in _anyLatexPattern.allMatches(text)) {
      expressions.add(match.group(0)!);
    }

    return expressions;
  }
}

/// Internal class to represent a LaTeX match
class _LaTeXMatch {
  final int start;
  final int end;
  final String content;
  final SegmentType type;

  const _LaTeXMatch({
    required this.start,
    required this.end,
    required this.content,
    required this.type,
  });
}
