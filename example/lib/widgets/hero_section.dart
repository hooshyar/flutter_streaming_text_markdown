import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

class HeroSection extends StatefulWidget {
  const HeroSection({super.key});

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection> {
  static const _heroDemo = '''## Welcome to the future of text streaming

This text is **streaming in real-time** — just like responses from ChatGPT or Claude.

- Supports full **Markdown** rendering
- Handles `inline code` and **bold** effortlessly
- Works with *any* Flutter app

> Built for developers who want beautiful streaming text.
''';

  int _key = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 48),
        Text(
          'flutter_streaming_text_markdown',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Streaming markdown for Flutter — like ChatGPT, but yours.',
          style: TextStyle(
            fontSize: 16,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          children: [
            _LinkChip('pub.dev', 'https://pub.dev/packages/flutter_streaming_text_markdown'),
            _LinkChip('GitHub', 'https://github.com/hooshyar/flutter_streaming_text_markdown'),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111111) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black12,
            ),
          ),
          child: StreamingTextMarkdown.chatGPT(
            key: ValueKey(_key),
            text: _heroDemo,
            markdownEnabled: true,
            padding: const EdgeInsets.all(16),
          ),
        ),
        Center(
          child: IconButton(
            icon: const Icon(Icons.replay, size: 18),
            tooltip: 'Replay',
            onPressed: () => setState(() => _key++),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _LinkChip extends StatelessWidget {
  final String label;
  final String url;
  const _LinkChip(this.label, this.url);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF00BCD4).withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? const Color(0xFF80DEEA) : const Color(0xFF00838F),
          ),
        ),
      ),
    );
  }
}
