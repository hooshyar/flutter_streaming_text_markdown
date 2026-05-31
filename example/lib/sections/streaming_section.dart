import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import '../shared/section_header.dart';
import '../shared/demo_card.dart';

/// Demonstrates the v1.9.0 `stream:` parameter — feeding a `Stream<String>`
/// (as you'd get from an LLM API) straight into [StreamingTextMarkdown] — plus
/// the `completeAnimationOnTap` toggle added in the same release.
class StreamingSection extends StatefulWidget {
  const StreamingSection({super.key});

  @override
  State<StreamingSection> createState() => _StreamingSectionState();
}

class _StreamingSectionState extends State<StreamingSection> {
  static const _accent = Color(0xFF00BCD4);

  // Markdown chunks, emitted one at a time the way an LLM streams tokens.
  static const _chunks = <String>[
    '## Streaming ',
    'from an **LLM**\n\n',
    'This text arrives ',
    'as a `Stream<String>` ',
    '— exactly like the ',
    'token deltas from ',
    'OpenAI or Anthropic.\n\n',
    'Each chunk is *appended* ',
    'and animated with the ',
    'active typing settings:\n\n',
    '- No buffering the whole reply\n',
    '- `trailingFadeEnabled` ',
    'for a smooth reveal\n',
    '- Per-character fade ',
    'auto-suppressed for streams\n\n',
    'Tap the text while it ',
    'streams to see ',
    '`completeAnimationOnTap` ',
    'in action.',
  ];

  int _runKey = 0;
  bool _completeOnTap = true;
  bool _isStreaming = false;

  /// A fresh single-subscription stream for each run. Mimics an LLM response:
  /// a short time-to-first-token, then steady token deltas.
  Stream<String> _fakeLlmStream() async* {
    await Future<void>.delayed(const Duration(milliseconds: 400)); // TTFT
    for (final chunk in _chunks) {
      yield chunk;
      await Future<void>.delayed(const Duration(milliseconds: 90));
    }
  }

  void _regenerate() {
    setState(() {
      _runKey++;
      _isStreaming = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Streaming'),
        DemoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 180),
                // Idle until the user starts a run, so we don't spin up a
                // stream (and its timers) on load. Tap "Start stream" to feed a
                // fresh `Stream<String>` into the widget.
                child: _runKey == 0
                    ? StreamingTextMarkdown.instant(
                        text: 'Tap **Start stream** to feed a '
                            '`Stream<String>` into `StreamingTextMarkdown` — '
                            'the same shape an LLM API hands you.',
                        markdownEnabled: true,
                        autoScroll: false,
                        padding: EdgeInsets.zero,
                      )
                    : StreamingTextMarkdown.chatGPT(
                        key: ValueKey('stream_$_runKey'),
                        stream: _fakeLlmStream(),
                        markdownEnabled: true,
                        trailingFadeEnabled: true, // recommended for streams
                        completeAnimationOnTap: _completeOnTap,
                        autoScroll: false,
                        padding: EdgeInsets.zero,
                        onComplete: () {
                          if (mounted) setState(() => _isStreaming = false);
                        },
                      ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _statusChip(isDark),
                  const Spacer(),
                  _controlBtn(
                    _isStreaming ? Icons.autorenew : Icons.send,
                    _runKey == 0 ? 'Start stream' : 'Regenerate',
                    _regenerate,
                    isDark,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // completeAnimationOnTap toggle
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'completeAnimationOnTap',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ),
                  Switch(
                    value: _completeOnTap,
                    activeThumbColor: _accent,
                    onChanged: (v) => setState(() => _completeOnTap = v),
                  ),
                ],
              ),
              Text(
                _completeOnTap
                    ? 'Tapping the text jumps to the finished response.'
                    : 'Taps pass through — the animation plays uninterrupted.',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _statusChip(bool isDark) {
    final label = _runKey == 0
        ? 'idle'
        : _isStreaming
            ? 'streaming…'
            : 'complete';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: _accent.withValues(alpha: 0.15),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _accent,
        ),
      ),
    );
  }

  Widget _controlBtn(
      IconData icon, String label, VoidCallback onTap, bool isDark) {
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
              Icon(icon,
                  size: 14, color: isDark ? Colors.white54 : Colors.black54),
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
