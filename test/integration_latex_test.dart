import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

void main() {
  group('LaTeX Integration Tests', () {
    testWidgets('Full LaTeX streaming animation cycle', (tester) async {
      bool animationCompleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingTextMarkdown(
              text: 'Equation: \$E = mc^2\$ is famous',
              latexEnabled: true,
              markdownEnabled: true,
              wordByWord: true,
              typingSpeed: const Duration(milliseconds: 100),
              onComplete: () {
                animationCompleted = true;
              },
            ),
          ),
        ),
      );

      // Initial state - no text should be visible yet
      await tester.pump(const Duration(milliseconds: 50));
      
      // Let some animation happen
      await tester.pump(const Duration(milliseconds: 200));
      
      // Should have some partial text
      expect(find.textContaining('Equation'), findsOneWidget);
      
      // Complete the animation
      await tester.pumpAndSettle(const Duration(seconds: 1));
      
      // Animation should be complete
      expect(animationCompleted, isTrue);
      expect(find.textContaining('famous'), findsOneWidget);
    });

    testWidgets('LaTeX streaming with real-time stream', (tester) async {
      final StreamController<String> controller = StreamController<String>();
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingText(
              text: '',
              stream: controller.stream,
              latexEnabled: true,
              markdownEnabled: true,
            ),
          ),
        ),
      );

      // Start with empty
      await tester.pump();
      expect(find.text(''), findsOneWidget);

      // Stream some text with LaTeX
      controller.add('Formula: ');
      await tester.pump();
      expect(find.textContaining('Formula:'), findsOneWidget);

      controller.add('\$x = 5\$');
      await tester.pump();

      controller.add(' and that is it');
      await tester.pump();
      expect(find.textContaining('and that is it'), findsOneWidget);

      // Close the stream
      await controller.close();
      await tester.pumpAndSettle(const Duration(seconds: 1));
    });

    testWidgets('Mixed markdown and LaTeX content streaming', (tester) async {
      const complexText = '''# Mathematical Concepts

## Quadratic Formula
The quadratic formula is: \$x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}\$

## Matrix Multiplication
Block formula:
\$\$
\\begin{pmatrix}
a & b \\\\
c & d
\\end{pmatrix}
\\begin{pmatrix}
e & f \\\\
g & h
\\end{pmatrix}
=
\\begin{pmatrix}
ae + bg & af + bh \\\\
ce + dg & cf + dh
\\end{pmatrix}
\$\$

This is **important** mathematics.''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StreamingTextMarkdown(
                text: complexText,
                latexEnabled: true,
                markdownEnabled: true,
                wordByWord: true,
                typingSpeed: const Duration(milliseconds: 10),
              ),
            ),
          ),
        ),
      );

      // Let animation progress
      await tester.pump(const Duration(milliseconds: 100));
      
      // Complete animation
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Should find markdown elements and text
      expect(find.textContaining('Mathematical Concepts'), findsOneWidget);
      expect(find.textContaining('Quadratic Formula'), findsOneWidget);
      expect(find.textContaining('Matrix Multiplication'), findsOneWidget);
      expect(find.textContaining('important'), findsOneWidget);
    });

    testWidgets('LaTeX animation with controller pause/resume', (tester) async {
      final controller = StreamingTextController();
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingTextMarkdown(
              text: 'Start \$a = b\$ middle \$\$c = d\$\$ end',
              latexEnabled: true,
              markdownEnabled: true,
              controller: controller,
              wordByWord: true,
              typingSpeed: const Duration(milliseconds: 50),
            ),
          ),
        ),
      );

      // Start animation
      await tester.pump(const Duration(milliseconds: 100));
      
      // Pause animation
      controller.pause();
      await tester.pump(const Duration(milliseconds: 100));
      
      // Resume animation
      controller.resume();
      await tester.pump(const Duration(milliseconds: 100));
      
      // Skip to end
      controller.skipToEnd();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.textContaining('Start'), findsOneWidget);
      expect(find.textContaining('end'), findsOneWidget);
    });

    testWidgets('Character-by-character LaTeX streaming', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingTextMarkdown(
              text: 'Hi \$x + y = z\$ bye',
              latexEnabled: true,
              markdownEnabled: true,
              wordByWord: false,
              chunkSize: 1,
              typingSpeed: const Duration(milliseconds: 30),
            ),
          ),
        ),
      );

      // Let some characters appear
      await tester.pump(const Duration(milliseconds: 100));
      
      // Should have partial text
      expect(find.textContaining('Hi'), findsOneWidget);
      
      // Complete animation
      await tester.pumpAndSettle(const Duration(seconds: 1));
      
      expect(find.textContaining('Hi'), findsOneWidget);
      expect(find.textContaining('bye'), findsOneWidget);
    });

    testWidgets('LaTeX streaming with Arabic RTL text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingTextMarkdown(
              text: 'مرحبا \$x = 5\$ بالعالم',
              latexEnabled: true,
              markdownEnabled: true,
              textDirection: TextDirection.rtl,
              wordByWord: true,
              typingSpeed: const Duration(milliseconds: 50),
            ),
          ),
        ),
      );

      // Let animation run
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.textContaining('مرحبا'), findsOneWidget);
      expect(find.textContaining('بالعالم'), findsOneWidget);
    });

    testWidgets('LaTeX streaming with fade-in animations', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingTextMarkdown(
              text: 'Fading \$a = b\$ text',
              latexEnabled: true,
              markdownEnabled: true,
              fadeInEnabled: true,
              fadeInDuration: const Duration(milliseconds: 200),
              latexFadeInEnabled: false, // LaTeX should not fade
              wordByWord: true,
              typingSpeed: const Duration(milliseconds: 50),
            ),
          ),
        ),
      );

      // Let animation run
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.textContaining('Fading'), findsOneWidget);
      expect(find.textContaining('text'), findsOneWidget);
    });

    testWidgets('Multiple LaTeX expressions in streaming', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingTextMarkdown(
              text: 'First \$x = 1\$ then \$y = 2\$ and \$\$z = 3\$\$ finally \$w = 4\$',
              latexEnabled: true,
              markdownEnabled: true,
              wordByWord: true,
              typingSpeed: const Duration(milliseconds: 50),
            ),
          ),
        ),
      );

      // Let animation progress through multiple expressions
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.textContaining('First'), findsOneWidget);
      expect(find.textContaining('then'), findsOneWidget);
      expect(find.textContaining('and'), findsOneWidget);
      expect(find.textContaining('finally'), findsOneWidget);
    });

    testWidgets('LaTeX streaming performance with large text', (tester) async {
      final largeText = '''# Large Document with LaTeX

${List.generate(10, (i) => 'Section $i: Formula \$x_$i = ${i + 1}\$').join('\n\n')}

## Final Formula
\$\$
\\sum_{i=1}^{10} x_i = ${List.generate(10, (i) => i + 1).join(' + ')}
\$\$

End of document.''';

      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StreamingTextMarkdown(
                text: largeText,
                latexEnabled: true,
                markdownEnabled: true,
                wordByWord: true,
                typingSpeed: const Duration(milliseconds: 1), // Fast for testing
              ),
            ),
          ),
        ),
      );

      // Let some animation happen
      await tester.pump(const Duration(milliseconds: 100));
      stopwatch.stop();

      // Should start animating in reasonable time (less than 1 second)
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      
      expect(find.textContaining('Large Document'), findsOneWidget);
      expect(find.textContaining('Final Formula'), findsOneWidget);
      expect(find.textContaining('End of document'), findsOneWidget);
    });

    testWidgets('LaTeX streaming with error handling', (tester) async {
      // Test with intentionally malformed LaTeX
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingTextMarkdown(
              text: 'Good \$x = 5\$ and bad \$unclosed and \$\$also unclosed',
              latexEnabled: true,
              markdownEnabled: true,
              wordByWord: true,
              typingSpeed: const Duration(milliseconds: 20),
            ),
          ),
        ),
      );

      // Should not crash - just pump a few frames
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      
      expect(find.textContaining('Good'), findsOneWidget);
    });
  });
}