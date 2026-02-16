import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class DemoFooter extends StatelessWidget {
  const DemoFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        const Divider(height: 48),
        GestureDetector(
          onTap: () {
            Clipboard.setData(const ClipboardData(text: 'flutter pub add flutter_streaming_text_markdown'));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!'), duration: Duration(seconds: 1)));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'flutter pub add flutter_streaming_text_markdown',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.copy, size: 14, color: isDark ? Colors.white38 : Colors.black38),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          children: [
            _link('pub.dev', 'https://pub.dev/packages/flutter_streaming_text_markdown', isDark),
            _link('GitHub', 'https://github.com/hooshyar/flutter_streaming_text_markdown', isDark),
            _link('License', 'https://github.com/hooshyar/flutter_streaming_text_markdown/blob/main/LICENSE', isDark),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _link(String label, String url, bool isDark) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url)),
      child: Text(label, style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF80DEEA) : const Color(0xFF00838F))),
    );
  }
}
