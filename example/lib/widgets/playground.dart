import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

class Playground extends StatefulWidget {
  const Playground({super.key});

  @override
  State<Playground> createState() => _PlaygroundState();
}

class _PlaygroundState extends State<Playground> {
  static const _presets = ['ChatGPT', 'Claude', 'Custom'];
  static const _responses = [
    '### Understanding Recursion\n\nRecursion is when a function **calls itself**. Every recursive function needs:\n\n1. A **base case** to stop\n2. A **recursive case** that moves toward it\n\n```python\ndef factorial(n):\n    if n <= 1: return 1\n    return n * factorial(n - 1)\n```\n\n> "To understand recursion, you must first understand recursion."',
    '## The Fibonacci Sequence\n\nEach number is the sum of the two before it: `0, 1, 1, 2, 3, 5, 8, 13...`\n\nApplications include:\n- **Nature**: spiral patterns in shells\n- **Finance**: technical analysis\n- **CS**: algorithm analysis\n\nThe golden ratio φ ≈ **1.618** emerges as the ratio converges.',
    '# Markdown Showcase\n\nThis demo renders **bold**, *italic*, and `code` inline.\n\n- Bullet lists work great\n- Even with **nested formatting**\n\n| Feature | Status |\n|---------|--------|\n| Streaming | ✅ |\n| Markdown | ✅ |\n\n---\n\n> Blockquotes render beautifully too.',
  ];

  int _presetIndex = 0;
  int _responseIndex = 0;
  int _textKey = 0;
  double _speed = 30;
  bool _wordByWord = false;
  bool _fadeIn = true;
  bool _showCustomize = false;

  void _generate() {
    setState(() {
      _responseIndex = (_responseIndex + 1) % _responses.length;
      _textKey++;
    });
  }

  void _selectPreset(int i) {
    setState(() {
      _presetIndex = i;
      if (i == 0) { _wordByWord = false; _fadeIn = true; _speed = 15; }
      if (i == 1) { _wordByWord = true; _fadeIn = true; _speed = 80; }
      _textKey++;
    });
  }

  Widget _buildStreamingWidget() {
    final text = _responses[_responseIndex];
    switch (_presetIndex) {
      case 0:
        return StreamingTextMarkdown.chatGPT(
          key: ValueKey(_textKey),
          text: text,
          markdownEnabled: true,
          padding: const EdgeInsets.all(16),
        );
      case 1:
        return StreamingTextMarkdown.claude(
          key: ValueKey(_textKey),
          text: text,
          markdownEnabled: true,
          padding: const EdgeInsets.all(16),
        );
      default:
        return StreamingTextMarkdown(
          key: ValueKey(_textKey),
          text: text,
          markdownEnabled: true,
          typingSpeed: Duration(milliseconds: _speed.round()),
          wordByWord: _wordByWord,
          fadeInEnabled: _fadeIn,
          fadeInDuration: const Duration(milliseconds: 200),
          fadeInCurve: Curves.easeOut,
          padding: const EdgeInsets.all(16),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Playground', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: List.generate(_presets.length, (i) => ChoiceChip(
            label: Text(_presets[i]),
            selected: _presetIndex == i,
            onSelected: (_) => _selectPreset(i),
            selectedColor: const Color(0xFF00BCD4).withValues(alpha: 0.25),
            side: BorderSide(color: _presetIndex == i ? const Color(0xFF00BCD4) : (isDark ? Colors.white24 : Colors.black12)),
            labelStyle: TextStyle(color: isDark ? Colors.white : Colors.black),
          )),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 180),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111111) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: _buildStreamingWidget(),
        ),
        const SizedBox(height: 12),
        Center(
          child: FilledButton.icon(
            onPressed: _generate,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Generate'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00BCD4)),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () {
              setState(() {
                _showCustomize = !_showCustomize;
                // Auto-switch to Custom when opening Customize
                if (_showCustomize && _presetIndex != 2) {
                  _presetIndex = 2;
                  _textKey++;
                }
              });
            },
            child: Text(_showCustomize ? 'Hide Customize ▲' : 'Customize ▼', style: const TextStyle(fontSize: 13)),
          ),
        ),
        if (_showCustomize) ...[
          Row(
            children: [
              Text('Speed: ${_speed.round()}ms', style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54)),
              Expanded(child: Slider(value: _speed, min: 5, max: 150, onChanged: (v) => setState(() => _speed = v), activeColor: const Color(0xFF00BCD4))),
            ],
          ),
          SwitchListTile(dense: true, title: const Text('Word-by-word', style: TextStyle(fontSize: 13)), value: _wordByWord, onChanged: (v) => setState(() => _wordByWord = v), activeTrackColor: const Color(0xFF00BCD4)),
          SwitchListTile(dense: true, title: const Text('Fade-in', style: TextStyle(fontSize: 13)), value: _fadeIn, onChanged: (v) => setState(() => _fadeIn = v), activeTrackColor: const Color(0xFF00BCD4)),
        ],
        const SizedBox(height: 32),
      ],
    );
  }
}
