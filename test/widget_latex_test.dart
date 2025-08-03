import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

void main() {
  group('LaTeX Widget Tests', () {
    testWidgets('StreamingTextMarkdown renders with LaTeX disabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingTextMarkdown(
              text: 'Hello \$x = 5\$ world',
              latexEnabled: false,
              markdownEnabled: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Should find the text with dollar signs intact (not rendered as LaTeX)
      expect(find.text('Hello \$x = 5\$ world'), findsOneWidget);
    });

    testWidgets('StreamingTextMarkdown renders with LaTeX enabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingTextMarkdown(
              text: 'The equation \$x = 5\$ is simple',
              latexEnabled: true,
              markdownEnabled: true,
              typingSpeed: Duration.zero, // Instant for testing
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 1));

      // The LaTeX should be processed, so the raw text won't be found
      expect(find.text('The equation \$x = 5\$ is simple'), findsNothing);
      
      // But we should find the regular text parts
      expect(find.textContaining('The equation'), findsOneWidget);
      expect(find.textContaining('is simple'), findsOneWidget);
    });

    testWidgets('StreamingTextMarkdown handles block LaTeX expressions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingTextMarkdown(
              text: 'Matrix: \$\$\\begin{matrix} a & b \\\\ c & d \\end{matrix}\$\$ Done',
              latexEnabled: true,
              markdownEnabled: true,
              typingSpeed: Duration.zero,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Should process the block LaTeX
      expect(find.textContaining('Matrix:'), findsOneWidget);
      expect(find.textContaining('Done'), findsOneWidget);
    });

    testWidgets('StreamingTextMarkdown.chatGPT with LaTeX enabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreamingTextMarkdown.chatGPT(
              text: 'Formula: \$E = mc^2\$',
              latexEnabled: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Should find the text parts
      expect(find.textContaining('Formula:'), findsOneWidget);
    });

    testWidgets('StreamingTextMarkdown.claude with LaTeX enabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreamingTextMarkdown.claude(
              text: 'The integral \$\\int_0^1 x dx = \\frac{1}{2}\$',
              latexEnabled: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.textContaining('The integral'), findsOneWidget);
    });

    testWidgets('StreamingTextMarkdown with custom LaTeX styling', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingTextMarkdown(
              text: 'Styled \$x = y\$ equation',
              latexEnabled: true,
              markdownEnabled: true,
              latexStyle: const TextStyle(
                color: Colors.blue,
                fontSize: 20,
              ),
              latexScale: 1.5,
              typingSpeed: Duration.zero,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.textContaining('Styled'), findsOneWidget);
      expect(find.textContaining('equation'), findsOneWidget);
    });

    testWidgets('StreamingTextMarkdown with mixed content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingTextMarkdown(
              text: '''# Math Examples
              
Inline math: \$x + y = z\$

Block math:
\$\$
\\sum_{i=1}^{n} i = \\frac{n(n+1)}{2}
\$\$

**Bold text** and *italic* text.''',
              latexEnabled: true,
              markdownEnabled: true,
              typingSpeed: Duration.zero,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Should find markdown headers and formatting
      expect(find.textContaining('Math Examples'), findsOneWidget);
      expect(find.textContaining('Inline math:'), findsOneWidget);
      expect(find.textContaining('Block math:'), findsOneWidget);
    });

    testWidgets('StreamingTextMarkdown handles LaTeX errors gracefully', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingTextMarkdown(
              text: 'Invalid \$unclosed LaTeX',
              latexEnabled: true,
              markdownEnabled: true,
              typingSpeed: Duration.zero,
            ),
          ),
        ),
      );

      // Should not crash and should render the text
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.textContaining('Invalid'), findsOneWidget);
    });

    testWidgets('StreamingTextMarkdown respects LaTeX fade-in settings', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingTextMarkdown(
              text: 'Equation \$a = b\$ here',
              latexEnabled: true,
              markdownEnabled: true,
              latexFadeInEnabled: false,
              fadeInEnabled: true,
              typingSpeed: const Duration(milliseconds: 10),
            ),
          ),
        ),
      );

      // Let animation run
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.textContaining('Equation'), findsOneWidget);
    });

    testWidgets('StreamingTextMarkdown theme integration', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingTextMarkdown(
              text: 'Themed \$x = 1\$ text',
              latexEnabled: true,
              markdownEnabled: true,
              theme: const StreamingTextTheme(
                inlineLatexStyle: TextStyle(color: Colors.red),
                latexScale: 1.2,
              ),
              typingSpeed: Duration.zero,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.textContaining('Themed'), findsOneWidget);
    });

    testWidgets('StreamingTextMarkdown atomic LaTeX during streaming', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingTextMarkdown(
              text: 'Start \$x = 5\$ middle \$\$y = 10\$\$ end',
              latexEnabled: true,
              markdownEnabled: true,
              wordByWord: true,
              typingSpeed: const Duration(milliseconds: 50),
            ),
          ),
        ),
      );

      // Let some animation happen
      await tester.pump(const Duration(milliseconds: 100));

      // Check that we can find some partial content
      final finder = find.byType(StreamingTextMarkdown);
      expect(finder, findsOneWidget);

      // Complete the animation
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.textContaining('Start'), findsOneWidget);
      expect(find.textContaining('end'), findsOneWidget);
    });

    testWidgets('StreamingTextMarkdown character-by-character with LaTeX', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingTextMarkdown(
              text: 'Hi \$x\$ ok',
              latexEnabled: true,
              markdownEnabled: true,
              wordByWord: false,
              typingSpeed: Duration.zero,
            ),
          ),
        ),
      );

      // Complete the animation
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.textContaining('Hi'), findsOneWidget);
      expect(find.textContaining('ok'), findsOneWidget);
    });

    testWidgets('StreamingTextMarkdown controller with LaTeX', (tester) async {
      final controller = StreamingTextController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingTextMarkdown(
              text: 'Control \$test = 1\$ example',
              latexEnabled: true,
              markdownEnabled: true,
              controller: controller,
              typingSpeed: Duration.zero,
            ),
          ),
        ),
      );

      // Start animation
      await tester.pump();

      // Skip to end using controller
      controller.skipToEnd();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.textContaining('Control'), findsOneWidget);
      expect(find.textContaining('example'), findsOneWidget);
    });

    testWidgets('StreamingTextMarkdown handles RTL text with LaTeX', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingTextMarkdown(
              text: 'مرحبا \$x = 5\$ عالم',
              latexEnabled: true,
              markdownEnabled: true,
              textDirection: TextDirection.rtl,
              typingSpeed: Duration.zero,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('مرحبا'), findsOneWidget);
      expect(find.textContaining('عالم'), findsOneWidget);
    });
  });
}