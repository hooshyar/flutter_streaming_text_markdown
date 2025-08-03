import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_streaming_text_markdown/src/utils/latex_processor.dart';

void main() {
  group('LaTeXProcessor', () {
    group('LaTeX Detection', () {
      test('should detect inline LaTeX expressions', () {
        expect(LaTeXProcessor.containsLaTeX('Hello \$x = 5\$ world'), isTrue);
        expect(LaTeXProcessor.containsInlineLaTeX('Hello \$x = 5\$ world'), isTrue);
        expect(LaTeXProcessor.containsBlockLaTeX('Hello \$x = 5\$ world'), isFalse);
      });

      test('should detect block LaTeX expressions', () {
        expect(LaTeXProcessor.containsLaTeX('Hello \$\$x = 5\$\$ world'), isTrue);
        expect(LaTeXProcessor.containsBlockLaTeX('Hello \$\$x = 5\$\$ world'), isTrue);
        expect(LaTeXProcessor.containsInlineLaTeX('Hello \$\$x = 5\$\$ world'), isFalse);
      });

      test('should detect mixed LaTeX expressions', () {
        const text = 'Inline \$a = b\$ and block \$\$c = d\$\$ math';
        expect(LaTeXProcessor.containsLaTeX(text), isTrue);
        expect(LaTeXProcessor.containsInlineLaTeX(text), isTrue);
        expect(LaTeXProcessor.containsBlockLaTeX(text), isTrue);
      });

      test('should not detect false positives', () {
        expect(LaTeXProcessor.containsLaTeX('Hello world'), isFalse);
        expect(LaTeXProcessor.containsLaTeX('Price: \$5'), isFalse);
        expect(LaTeXProcessor.containsLaTeX('Cost \$10 - \$20'), isFalse);
        expect(LaTeXProcessor.containsLaTeX('\$ alone'), isFalse);
      });
    });

    group('LaTeX Expression Counting', () {
      test('should count LaTeX expressions correctly', () {
        expect(LaTeXProcessor.countLatexExpressions('No math here'), equals(0));
        expect(LaTeXProcessor.countLatexExpressions('One \$x = 5\$ expression'), equals(1));
        expect(LaTeXProcessor.countLatexExpressions('Two \$x = 5\$ and \$y = 10\$ expressions'), equals(2));
        expect(LaTeXProcessor.countLatexExpressions('Block \$\$z = 15\$\$ expression'), equals(1));
        expect(LaTeXProcessor.countLatexExpressions('Mixed \$a = b\$ and \$\$c = d\$\$ expressions'), equals(2));
      });
    });

    group('LaTeX Expression Extraction', () {
      test('should extract LaTeX expressions', () {
        const text = 'Formula \$E = mc^2\$ and matrix \$\$\\begin{matrix} a & b \\\\ c & d \\end{matrix}\$\$';
        final expressions = LaTeXProcessor.extractLatexExpressions(text);
        expect(expressions, hasLength(2));
        expect(expressions[0], equals('\$E = mc^2\$'));
        expect(expressions[1], equals('\$\$\\begin{matrix} a & b \\\\ c & d \\end{matrix}\$\$'));
      });
    });

    group('Text Segmentation', () {
      test('should parse text with no LaTeX', () {
        const text = 'Hello world';
        final segments = LaTeXProcessor.parseTextSegments(text);
        expect(segments, hasLength(1));
        expect(segments[0].content, equals('Hello world'));
        expect(segments[0].type, equals(SegmentType.regular));
        expect(segments[0].isLaTeX, isFalse);
      });

      test('should parse text with inline LaTeX', () {
        const text = 'The equation \$x = 5\$ is simple';
        final segments = LaTeXProcessor.parseTextSegments(text);
        expect(segments, hasLength(3));
        
        expect(segments[0].content, equals('The equation '));
        expect(segments[0].type, equals(SegmentType.regular));
        
        expect(segments[1].content, equals('x = 5'));
        expect(segments[1].type, equals(SegmentType.inlineLaTeX));
        expect(segments[1].isLaTeX, isTrue);
        expect(segments[1].fullExpression, equals('\$x = 5\$'));
        
        expect(segments[2].content, equals(' is simple'));
        expect(segments[2].type, equals(SegmentType.regular));
      });

      test('should parse text with block LaTeX', () {
        const text = 'Matrix:\$\$\\begin{matrix} a & b \\\\ c & d \\end{matrix}\$\$End';
        final segments = LaTeXProcessor.parseTextSegments(text);
        expect(segments, hasLength(3));
        
        expect(segments[0].content, equals('Matrix:'));
        expect(segments[0].type, equals(SegmentType.regular));
        
        expect(segments[1].content, equals('\\begin{matrix} a & b \\\\ c & d \\end{matrix}'));
        expect(segments[1].type, equals(SegmentType.blockLaTeX));
        expect(segments[1].isLaTeX, isTrue);
        expect(segments[1].fullExpression, equals('\$\$\\begin{matrix} a & b \\\\ c & d \\end{matrix}\$\$'));
        
        expect(segments[2].content, equals('End'));
        expect(segments[2].type, equals(SegmentType.regular));
      });

      test('should parse text with mixed LaTeX', () {
        const text = 'Inline \$a = b\$ and block \$\$c = d\$\$ math';
        final segments = LaTeXProcessor.parseTextSegments(text);
        expect(segments, hasLength(5));
        
        expect(segments[0].content, equals('Inline '));
        expect(segments[0].type, equals(SegmentType.regular));
        
        expect(segments[1].content, equals('a = b'));
        expect(segments[1].type, equals(SegmentType.inlineLaTeX));
        
        expect(segments[2].content, equals(' and block '));
        expect(segments[2].type, equals(SegmentType.regular));
        
        expect(segments[3].content, equals('c = d'));
        expect(segments[3].type, equals(SegmentType.blockLaTeX));
        
        expect(segments[4].content, equals(' math'));
        expect(segments[4].type, equals(SegmentType.regular));
      });

      test('should handle multiple LaTeX expressions with spaces', () {
        const text = '\$a = 1\$ \$b = 2\$ and \$\$c = 3\$\$ \$\$d = 4\$\$';
        final segments = LaTeXProcessor.parseTextSegments(text);
        expect(segments, hasLength(7));
        
        expect(segments[0].content, equals('a = 1'));
        expect(segments[0].type, equals(SegmentType.inlineLaTeX));
        
        expect(segments[1].content, equals(' '));
        expect(segments[1].type, equals(SegmentType.regular));
        
        expect(segments[2].content, equals('b = 2'));
        expect(segments[2].type, equals(SegmentType.inlineLaTeX));
        
        expect(segments[3].content, equals(' and '));
        expect(segments[3].type, equals(SegmentType.regular));
        
        expect(segments[4].content, equals('c = 3'));
        expect(segments[4].type, equals(SegmentType.blockLaTeX));
        
        expect(segments[5].content, equals(' '));
        expect(segments[5].type, equals(SegmentType.regular));
        
        expect(segments[6].content, equals('d = 4'));
        expect(segments[6].type, equals(SegmentType.blockLaTeX));
      });

      test('should prioritize block LaTeX over inline when overlapping', () {
        // In practice, this shouldn't happen, but test the precedence
        const text = 'Text \$\$a + b\$\$ more text';
        final segments = LaTeXProcessor.parseTextSegments(text);
        expect(segments, hasLength(3));
        
        expect(segments[1].type, equals(SegmentType.blockLaTeX));
        expect(segments[1].content, equals('a + b'));
      });
    });

    group('Position Checking', () {
      test('should correctly identify positions within LaTeX', () {
        const text = 'Hello \$x = 5\$ world \$\$y = 10\$\$ end';
        //             01234567890123456789012345678901234567
        //                   ^     ^          ^
        //                   7     13         25

        expect(LaTeXProcessor.isPositionInLatex(text, 5), isFalse); // Before LaTeX
        expect(LaTeXProcessor.isPositionInLatex(text, 7), isTrue);  // Inside inline LaTeX
        expect(LaTeXProcessor.isPositionInLatex(text, 9), isTrue);  // Inside inline LaTeX
        expect(LaTeXProcessor.isPositionInLatex(text, 13), isFalse); // After inline LaTeX
        expect(LaTeXProcessor.isPositionInLatex(text, 25), isTrue);  // Inside block LaTeX
        expect(LaTeXProcessor.isPositionInLatex(text, 35), isFalse); // After block LaTeX
      });

      test('should get LaTeX indices correctly', () {
        const text = 'Hello \$x = 5\$ world \$\$y = 10\$\$ end';
        final indices = LaTeXProcessor.getLatexIndices(text);
        expect(indices, hasLength(2));
        expect(indices[0], equals((6, 13))); // \$x = 5\$
        expect(indices[1], equals((20, 30))); // \$\$y = 10\$\$
      });
    });

    group('Edge Cases', () {
      test('should handle empty text', () {
        expect(LaTeXProcessor.containsLaTeX(''), isFalse);
        expect(LaTeXProcessor.parseTextSegments(''), isEmpty);
        expect(LaTeXProcessor.countLatexExpressions(''), equals(0));
        expect(LaTeXProcessor.extractLatexExpressions(''), isEmpty);
      });

      test('should handle text with only LaTeX', () {
        const text = '\$x = 5\$';
        final segments = LaTeXProcessor.parseTextSegments(text);
        expect(segments, hasLength(1));
        expect(segments[0].type, equals(SegmentType.inlineLaTeX));
        expect(segments[0].content, equals('x = 5'));
      });

      test('should handle malformed LaTeX gracefully', () {
        // Unclosed expressions
        expect(LaTeXProcessor.containsLaTeX('\$x = 5'), isFalse);
        expect(LaTeXProcessor.containsLaTeX('x = 5\$'), isFalse);
        expect(LaTeXProcessor.containsLaTeX('\$\$x = 5'), isFalse);
        expect(LaTeXProcessor.containsLaTeX('x = 5\$\$'), isFalse);
        
        // Empty expressions
        expect(LaTeXProcessor.containsLaTeX('\$\$'), isFalse);
        expect(LaTeXProcessor.containsLaTeX('\$\$\$\$'), isFalse);
      });

      test('should handle complex mathematical expressions', () {
        const complexFormula = '\$\\sum_{i=1}^{n} \\frac{1}{i^2} = \\frac{\\pi^2}{6}\$';
        expect(LaTeXProcessor.containsLaTeX(complexFormula), isTrue);
        final segments = LaTeXProcessor.parseTextSegments(complexFormula);
        expect(segments, hasLength(1));
        expect(segments[0].type, equals(SegmentType.inlineLaTeX));
      });

      test('should handle LaTeX with special characters', () {
        const formula = '\$\\alpha + \\beta = \\gamma \\cdot \\delta\$';
        expect(LaTeXProcessor.containsLaTeX(formula), isTrue);
        final segments = LaTeXProcessor.parseTextSegments(formula);
        expect(segments, hasLength(1));
        expect(segments[0].content, equals('\\alpha + \\beta = \\gamma \\cdot \\delta'));
      });
    });
  });
}