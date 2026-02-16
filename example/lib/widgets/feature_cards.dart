import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

class FeatureCards extends StatelessWidget {
  const FeatureCards({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cards = <Widget>[
      const _RTLCard(),
      const _LatexCard(),
      const _ControlCard(),
    ];
    if (w > 720) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))).toList(),
      );
    }
    return Column(children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList());
  }
}

class _CardShell extends StatelessWidget {
  final String emoji;
  final String title;
  final Widget child;
  final VoidCallback? onReplay;
  const _CardShell({required this.emoji, required this.title, required this.child, this.onReplay});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('$emoji  $title', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
              if (onReplay != null)
                IconButton(
                  icon: const Icon(Icons.replay, size: 18),
                  tooltip: 'Replay',
                  onPressed: onReplay,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
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

class _RTLCard extends StatefulWidget {
  const _RTLCard();
  @override
  State<_RTLCard> createState() => _RTLCardState();
}

class _RTLCardState extends State<_RTLCard> {
  int _key = 0;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      emoji: '🌍',
      title: 'RTL Support',
      onReplay: () => setState(() => _key++),
      child: StreamingTextMarkdown(
        key: ValueKey(_key),
        text: 'مرحباً بالعالم! هذا **نص عربي** يتدفق بشكل جميل من اليمين إلى اليسار.',
        textDirection: TextDirection.rtl,
        typingSpeed: const Duration(milliseconds: 100),
        wordByWord: true,
        markdownEnabled: true,
        padding: const EdgeInsets.all(0),
      ),
    );
  }
}

class _LatexCard extends StatefulWidget {
  const _LatexCard();
  @override
  State<_LatexCard> createState() => _LatexCardState();
}

class _LatexCardState extends State<_LatexCard> {
  int _key = 0;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      emoji: '📐',
      title: 'LaTeX',
      onReplay: () => setState(() => _key++),
      child: StreamingTextMarkdown(
        key: ValueKey(_key),
        text: r'Euler: $e^{i\pi} + 1 = 0$. Quadratic: $x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}$',
        typingSpeed: const Duration(milliseconds: 40),
        latexEnabled: true,
        markdownEnabled: true,
        padding: const EdgeInsets.all(0),
      ),
    );
  }
}

class _ControlCard extends StatefulWidget {
  const _ControlCard();
  @override
  State<_ControlCard> createState() => _ControlCardState();
}

class _ControlCardState extends State<_ControlCard> {
  final _ctrl = StreamingTextController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      emoji: '🎛️',
      title: 'Programmatic Control',
      child: Column(
        children: [
          StreamingTextMarkdown(
            text: 'This animation can be **paused**, **resumed**, or **skipped** programmatically via the controller API.',
            typingSpeed: const Duration(milliseconds: 60),
            wordByWord: true,
            markdownEnabled: true,
            controller: _ctrl,
            padding: const EdgeInsets.all(0),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(icon: const Icon(Icons.pause, size: 20), onPressed: _ctrl.pause, tooltip: 'Pause'),
              IconButton(icon: const Icon(Icons.play_arrow, size: 20), onPressed: _ctrl.resume, tooltip: 'Resume'),
              IconButton(icon: const Icon(Icons.skip_next, size: 20), onPressed: _ctrl.skipToEnd, tooltip: 'Skip'),
              IconButton(icon: const Icon(Icons.replay, size: 20), onPressed: _ctrl.restart, tooltip: 'Restart'),
            ],
          ),
        ],
      ),
    );
  }
}
