import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import '../shared/section_header.dart';
import '../shared/demo_card.dart';

class FeaturesSection extends StatefulWidget {
  const FeaturesSection({super.key});

  @override
  State<FeaturesSection> createState() => _FeaturesSectionState();
}

class _FeaturesSectionState extends State<FeaturesSection> {
  int _mdKey = 0;
  int _latexKey = 0;
  int _rtlKey = 0;

  static const _markdownText =
      '# Heading 1\n## Heading 2\n\n'
      '**Bold text** and *italic text* and `inline code`.\n\n'
      '- List item one\n- List item two\n\n'
      '> A beautiful blockquote\n\n'
      '| Column A | Column B |\n|----------|----------|\n| Cell 1   | Cell 2   |';

  static const _latexText =
      'The quadratic formula: \$x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}\$\n\n'
      'Euler\'s identity: \$e^{i\\pi} + 1 = 0\$\n\n'
      'Block equation:\n\$\$\\int_0^\\infty e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2}\$\$';

  static const _rtlText =
      '## مرحباً بالعالم 👋\n\n'
      'هذا نص **عربي** يتم عرضه بتقنية البث المباشر.\n\n'
      '- دعم كامل للغة العربية\n'
      '- عرض من اليمين لليسار\n\n'
      '> تم بناؤه بحب لمجتمع فلاتر.';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Features'),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            final children = [
              _featureCard(
                context,
                title: 'Markdown',
                subtitle: 'markdownEnabled: true',
                replayKey: _mdKey,
                onReplay: () => setState(() => _mdKey++),
                child: StreamingTextMarkdown.claude(
                  key: ValueKey('md_$_mdKey'),
                  text: _markdownText,
                  autoScroll: false,
                  padding: EdgeInsets.zero,
                ),
              ),
              _featureCard(
                context,
                title: 'LaTeX',
                subtitle: 'latexEnabled: true',
                replayKey: _latexKey,
                onReplay: () => setState(() => _latexKey++),
                child: StreamingTextMarkdown.chatGPT(
                  key: ValueKey('latex_$_latexKey'),
                  text: _latexText,
                  latexEnabled: true,
                  autoScroll: false,
                  padding: EdgeInsets.zero,
                ),
              ),
              _featureCard(
                context,
                title: 'RTL Support',
                subtitle: 'textDirection: TextDirection.rtl',
                replayKey: _rtlKey,
                onReplay: () => setState(() => _rtlKey++),
                child: StreamingTextMarkdown.fromPreset(
                  key: ValueKey('rtl_$_rtlKey'),
                  text: _rtlText,
                  preset: LLMAnimationPresets.rtlOptimized,
                  markdownEnabled: true,
                  textDirection: TextDirection.rtl,
                  autoScroll: false,
                  padding: EdgeInsets.zero,
                ),
              ),
            ];

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: children[0]),
                  const SizedBox(width: 12),
                  Expanded(child: children[1]),
                  const SizedBox(width: 12),
                  Expanded(child: children[2]),
                ],
              );
            }
            return Column(
              children: children.map((c) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: c,
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _featureCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required int replayKey,
    required VoidCallback onReplay,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DemoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onReplay,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Icon(
                    Icons.replay_rounded,
                    size: 16,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
