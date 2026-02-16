import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import '../shared/demo_card.dart';

class HeroSection extends StatefulWidget {
  final StreamingTextConfig? activePreset;
  final String? activePresetName;

  const HeroSection({super.key, this.activePreset, this.activePresetName});

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection> {
  int _heroKey = 0;

  static const _heroText =
      '## Hello, World! 👋\n\n'
      'This is **flutter_streaming_text_markdown** — a package for rendering '
      'streaming text with full **Markdown** support.\n\n'
      'Perfect for building:\n'
      '- 🤖 AI chat interfaces\n'
      '- 💬 Real-time messaging\n'
      '- ✍️ Typing animations\n\n'
      '> Built with love for the Flutter community.';

  @override
  void didUpdateWidget(HeroSection old) {
    super.didUpdateWidget(old);
    if (old.activePreset != widget.activePreset) {
      setState(() => _heroKey++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = const Color(0xFF00BCD4);
    final preset = widget.activePreset;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 48),
        Text(
          'flutter_streaming_text_markdown',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Streaming markdown for Flutter',
          style: TextStyle(
            fontSize: 16,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            _chip('pub.dev', accent),
            _chip('GitHub', accent),
            _chip('v1.4.0', isDark ? Colors.white24 : Colors.black26),
          ],
        ),
        const SizedBox(height: 32),
        if (widget.activePresetName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome, size: 14, color: accent),
                const SizedBox(width: 6),
                Text(
                  'Preset: ${widget.activePresetName}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        DemoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => setState(() => _heroKey++),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Icon(
                    Icons.replay_rounded,
                    size: 18,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
              if (preset != null)
                StreamingTextMarkdown.fromPreset(
                  key: ValueKey('hero_$_heroKey'),
                  text: _heroText,
                  preset: preset,
                  markdownEnabled: true,
                  autoScroll: false,
                  padding: EdgeInsets.zero,
                )
              else
                StreamingTextMarkdown.chatGPT(
                  key: ValueKey('hero_$_heroKey'),
                  text: _heroText,
                  autoScroll: false,
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color),
      ),
    );
  }
}
