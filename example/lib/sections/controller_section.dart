import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import '../shared/section_header.dart';
import '../shared/demo_card.dart';

class ControllerSection extends StatefulWidget {
  const ControllerSection({super.key});

  @override
  State<ControllerSection> createState() => _ControllerSectionState();
}

class _ControllerSectionState extends State<ControllerSection> {
  final _controller = StreamingTextController();
  double _progress = 0.0;
  StreamingTextState _state = StreamingTextState.idle;
  double _speed = 1.0;
  final int _key = 0;

  static const _text =
      '## Streaming Text Controller\n\n'
      'This text is being animated with a **StreamingTextController**. You can:\n\n'
      '1. **Pause** the animation mid-stream\n'
      '2. **Resume** from exactly where you left off\n'
      '3. **Skip** to see the full text instantly\n'
      '4. **Restart** from the beginning\n'
      '5. Adjust the **speed multiplier** in real-time\n\n'
      'The progress bar below tracks the animation progress from 0% to 100%.';

  @override
  void initState() {
    super.initState();
    _setupCallbacks();
  }

  void _setupCallbacks() {
    _controller.onProgressChanged((p) {
      if (mounted) setState(() => _progress = p);
    });
    _controller.onStateChanged((s) {
      if (mounted) setState(() => _state = s);
    });
    _controller.onCompleted(() {
      if (mounted) setState(() => _state = StreamingTextState.completed);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = const Color(0xFF00BCD4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Controller'),
        DemoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StreamingTextMarkdown.claude(
                key: ValueKey('ctrl_$_key'),
                text: _text,
                controller: _controller,
                autoScroll: false,
                padding: EdgeInsets.zero,
                onComplete: () {
                  if (mounted) {
                    setState(() => _state = StreamingTextState.completed);
                  }
                },
              ),
              const SizedBox(height: 20),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: isDark ? Colors.white10 : Colors.black12,
                  valueColor: AlwaysStoppedAnimation(accent),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _stateChip(_state.description, isDark, accent),
                  const Spacer(),
                  Text(
                    '${(_progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Control buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _controlBtn(Icons.pause, 'Pause', () => _controller.pause(), isDark),
                  _controlBtn(Icons.play_arrow, 'Resume', () => _controller.resume(), isDark),
                  _controlBtn(Icons.skip_next, 'Skip', () => _controller.skipToEnd(), isDark),
                  _controlBtn(Icons.replay, 'Restart', () {
                    _controller.restart();
                    setState(() {
                      _progress = 0;
                      _state = StreamingTextState.animating;
                    });
                  }, isDark),
                  _controlBtn(Icons.stop, 'Stop', () => _controller.stop(), isDark),
                ],
              ),
              const SizedBox(height: 16),
              // Speed slider
              Row(
                children: [
                  Text(
                    'Speed: ${_speed.toStringAsFixed(1)}x',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: _speed,
                      min: 0.5,
                      max: 3.0,
                      divisions: 10,
                      activeColor: accent,
                      onChanged: (v) {
                        setState(() => _speed = v);
                        _controller.speedMultiplier = v;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _stateChip(String label, bool isDark, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: accent.withValues(alpha: 0.15),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accent),
      ),
    );
  }

  Widget _controlBtn(IconData icon, String label, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: isDark ? Colors.white54 : Colors.black54),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
