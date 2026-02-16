import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import '../shared/section_header.dart';
import '../shared/demo_card.dart';

class ThemeSection extends StatefulWidget {
  const ThemeSection({super.key});

  @override
  State<ThemeSection> createState() => _ThemeSectionState();
}

class _ThemeSectionState extends State<ThemeSection> {
  int _key = 0;

  static const _text =
      '## Theme Extension\n\n'
      'This text uses a **custom StreamingTextTheme** applied via '
      'ThemeExtension.\n\n'
      'Access it anywhere with `context.streamingTextTheme`.';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Theme'),
        DemoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'StreamingTextTheme as ThemeExtension',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _key++),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Icon(Icons.replay_rounded, size: 16,
                        color: isDark ? Colors.white38 : Colors.black38),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Custom textStyle, markdownStyleSheet, padding, latexStyle',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
              ),
              const SizedBox(height: 16),
              // Themed demo with custom StreamingTextTheme
              Theme(
                data: Theme.of(context).copyWith(
                  extensions: [
                    StreamingTextTheme(
                      textStyle: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: isDark ? const Color(0xFFB0BEC5) : const Color(0xFF37474F),
                      ),
                      markdownStyleSheet: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: isDark ? const Color(0xFFB0BEC5) : const Color(0xFF37474F),
                      ),
                      defaultPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
                child: StreamingTextMarkdown.claude(
                  key: ValueKey('theme_$_key'),
                  text: _text,
                  autoScroll: false,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }
}
