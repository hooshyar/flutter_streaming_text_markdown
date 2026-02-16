import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../shared/section_header.dart';
import '../shared/demo_card.dart';

class FooterSection extends StatelessWidget {
  const FooterSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = const Color(0xFF00BCD4);
    final mutedColor = isDark ? Colors.white38 : Colors.black38;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Install'),
        DemoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      'flutter pub add flutter_streaming_text_markdown',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(const ClipboardData(
                        text: 'flutter pub add flutter_streaming_text_markdown',
                      ));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Copied to clipboard'),
                          backgroundColor: accent,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Icon(Icons.copy, size: 16, color: mutedColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _link('pub.dev', accent),
            const SizedBox(width: 24),
            _link('GitHub', accent),
            const SizedBox(width: 24),
            _link('MIT License', mutedColor),
          ],
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _link(String label, Color color) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color,
      ),
    );
  }
}
