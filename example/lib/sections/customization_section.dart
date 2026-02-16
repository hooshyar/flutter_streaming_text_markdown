import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import '../shared/section_header.dart';
import '../shared/demo_card.dart';

class CustomizationSection extends StatefulWidget {
  const CustomizationSection({super.key});

  @override
  State<CustomizationSection> createState() => _CustomizationSectionState();
}

class _CustomizationSectionState extends State<CustomizationSection> {
  double _speed = 50;
  double _fadeInMs = 200;
  bool _wordByWord = false;
  bool _fadeInEnabled = true;
  bool _markdownEnabled = true;
  bool _latexEnabled = false;
  bool _animationsEnabled = true;
  int _chunkSize = 1;
  String _curveName = 'easeOut';
  int _key = 0;

  static const _sampleText =
      '## Customization Preview\n\n'
      'Adjust the controls below to see how each parameter affects the streaming animation.\n\n'
      '**Bold**, *italic*, `code` — all rendered with markdown.\n\n'
      '- Item one\n- Item two\n\n'
      '> Streaming text, your way.';

  static const _curveMap = {
    'easeOut': Curves.easeOut,
    'easeInOut': Curves.easeInOut,
    'bounceOut': Curves.bounceOut,
    'decelerate': Curves.decelerate,
    'elasticOut': Curves.elasticOut,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = const Color(0xFF00BCD4);
    final labelStyle = TextStyle(
      fontSize: 12,
      color: isDark ? Colors.white54 : Colors.black54,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Customization'),
        // Preview
        DemoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => setState(() => _key++),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Icon(Icons.replay_rounded, size: 16,
                    color: isDark ? Colors.white38 : Colors.black38),
                ),
              ),
              StreamingTextMarkdown(
                key: ValueKey('custom_${_key}_${_speed}_${_fadeInMs}_${_wordByWord}_${_chunkSize}_${_curveName}_${_fadeInEnabled}_${_markdownEnabled}_${_latexEnabled}_$_animationsEnabled'),
                text: _sampleText,
                typingSpeed: Duration(milliseconds: _speed.round()),
                fadeInEnabled: _fadeInEnabled,
                fadeInDuration: Duration(milliseconds: _fadeInMs.round()),
                fadeInCurve: _curveMap[_curveName] ?? Curves.easeOut,
                wordByWord: _wordByWord,
                chunkSize: _chunkSize,
                markdownEnabled: _markdownEnabled,
                latexEnabled: _latexEnabled,
                animationsEnabled: _animationsEnabled,
                autoScroll: false,
                padding: EdgeInsets.zero,
                initialText: '',
                onComplete: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Controls
        DemoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Speed slider
              Row(
                children: [
                  SizedBox(width: 120, child: Text('Typing speed', style: labelStyle)),
                  Expanded(
                    child: Slider(
                      value: _speed,
                      min: 5,
                      max: 200,
                      activeColor: accent,
                      onChanged: (v) => setState(() { _speed = v; _key++; }),
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text('${_speed.round()}ms', style: labelStyle),
                  ),
                ],
              ),
              // Fade-in duration
              Row(
                children: [
                  SizedBox(width: 120, child: Text('Fade-in duration', style: labelStyle)),
                  Expanded(
                    child: Slider(
                      value: _fadeInMs,
                      min: 0,
                      max: 600,
                      activeColor: accent,
                      onChanged: (v) => setState(() { _fadeInMs = v; _key++; }),
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text('${_fadeInMs.round()}ms', style: labelStyle),
                  ),
                ],
              ),
              // Chunk size
              Row(
                children: [
                  SizedBox(width: 120, child: Text('Chunk size', style: labelStyle)),
                  Expanded(
                    child: Slider(
                      value: _chunkSize.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      activeColor: accent,
                      onChanged: (v) => setState(() { _chunkSize = v.round(); _key++; }),
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text('$_chunkSize', style: labelStyle),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Fade-in curve dropdown
              Row(
                children: [
                  SizedBox(width: 120, child: Text('Fade-in curve', style: labelStyle)),
                  DropdownButton<String>(
                    value: _curveName,
                    dropdownColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                    underline: const SizedBox(),
                    items: _curveMap.keys.map((name) {
                      return DropdownMenuItem(value: name, child: Text(name));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() { _curveName = v; _key++; });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Toggles
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _toggle('wordByWord', _wordByWord, (v) => setState(() { _wordByWord = v; _key++; }), isDark, accent),
                  _toggle('fadeIn', _fadeInEnabled, (v) => setState(() { _fadeInEnabled = v; _key++; }), isDark, accent),
                  _toggle('markdown', _markdownEnabled, (v) => setState(() { _markdownEnabled = v; _key++; }), isDark, accent),
                  _toggle('latex', _latexEnabled, (v) => setState(() { _latexEnabled = v; _key++; }), isDark, accent),
                  _toggle('animations', _animationsEnabled, (v) => setState(() { _animationsEnabled = v; _key++; }), isDark, accent),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged, bool isDark, Color accent) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 24,
          width: 36,
          child: Switch(
            value: value,
            activeTrackColor: accent,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ],
    );
  }
}
