import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import '../shared/section_header.dart';
import '../shared/demo_card.dart';

class _PresetInfo {
  final String name;
  final String preview;
  final StreamingTextConfig config;
  final String details;

  const _PresetInfo({
    required this.name,
    required this.preview,
    required this.config,
    required this.details,
  });
}

class PresetsSection extends StatefulWidget {
  final ValueChanged<(StreamingTextConfig, String)> onPresetSelected;

  const PresetsSection({super.key, required this.onPresetSelected});

  @override
  State<PresetsSection> createState() => _PresetsSectionState();
}

class _PresetsSectionState extends State<PresetsSection> {
  int? _selectedIndex;
  final Map<int, int> _replayKeys = {};

  static final _presets = [
    _PresetInfo(
      name: 'chatGPT',
      preview: 'Fast character streaming with fade-in...',
      config: LLMAnimationPresets.chatGPT,
      details: 'char · 15ms · fadeIn',
    ),
    _PresetInfo(
      name: 'claude',
      preview: 'Smooth word-by-word delivery...',
      config: LLMAnimationPresets.claude,
      details: 'word · 80ms · fadeIn',
    ),
    _PresetInfo(
      name: 'typewriter',
      preview: 'Classic mechanical typewriter feel...',
      config: LLMAnimationPresets.typewriter,
      details: 'char · 50ms · no fade',
    ),
    _PresetInfo(
      name: 'instant',
      preview: 'No animation, instant display.',
      config: LLMAnimationPresets.instant,
      details: 'instant · no anim',
    ),
    _PresetInfo(
      name: 'gentle',
      preview: 'Slow, graceful word appearance...',
      config: LLMAnimationPresets.gentle,
      details: 'word · 100ms · 400ms fade',
    ),
    _PresetInfo(
      name: 'bouncy',
      preview: 'Playful bounce on each word...',
      config: LLMAnimationPresets.bouncy,
      details: 'word · 60ms · bounceOut',
    ),
    _PresetInfo(
      name: 'chunks',
      preview: 'Fast 3-character chunk delivery...',
      config: LLMAnimationPresets.chunks,
      details: 'chunk(3) · 30ms · fadeIn',
    ),
    _PresetInfo(
      name: 'rtlOptimized',
      preview: 'مرحباً بالعالم — مُحسَّن للعربية',
      config: LLMAnimationPresets.rtlOptimized,
      details: 'word · 100ms · RTL',
    ),
    _PresetInfo(
      name: 'professional',
      preview: 'Polished, measured word delivery...',
      config: LLMAnimationPresets.professional,
      details: 'word · 40ms · decelerate',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = const Color(0xFF00BCD4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Presets'),
        Text(
          '9 built-in presets via LLMAnimationPresets — click to preview in hero above',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white38 : Colors.black45,
          ),
        ),
        const SizedBox(height: 16),
        // Speed system demo
        DemoCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.speed, size: 16, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Speed system: LLMAnimationPresets.bySpeed(AnimationSpeed.slow / medium / fast / ultraFast)',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.3,
              ),
              itemCount: _presets.length,
              itemBuilder: (context, i) {
                final p = _presets[i];
                final isSelected = _selectedIndex == i;
                final replayKey = _replayKeys[i] ?? 0;
                final isRtl = p.name == 'rtlOptimized';

                return DemoCard(
                  onTap: () {
                    setState(() {
                      _selectedIndex = i;
                      _replayKeys[i] = replayKey + 1;
                    });
                    widget.onPresetSelected((p.config, p.name));
                  },
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isSelected)
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              p.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? accent
                                    : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.details,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white24 : Colors.black26,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ClipRect(
                          child: StreamingTextMarkdown.fromPreset(
                            key: ValueKey('preset_${p.name}_$replayKey'),
                            text: p.preview,
                            preset: p.config,
                            markdownEnabled: false,
                            autoScroll: false,
                            textDirection: isRtl ? TextDirection.rtl : null,
                            padding: EdgeInsets.zero,
                            animationsEnabled: p.name != 'instant',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 48),
      ],
    );
  }
}
