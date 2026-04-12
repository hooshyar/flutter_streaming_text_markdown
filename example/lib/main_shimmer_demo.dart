import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

void main() => runApp(const ShimmerTestApp());

class ShimmerTestApp extends StatefulWidget {
  const ShimmerTestApp({super.key});

  @override
  State<ShimmerTestApp> createState() => _ShimmerTestAppState();
}

class _ShimmerTestAppState extends State<ShimmerTestApp> {
  bool _isLoading = true;
  final String _text = '''# Welcome to v1.6.0!

This is the new **shimmer loading state** feature.

When `isLoading: true`, you see an animated skeleton placeholder instead of blank space.

Now you can:
- Show a nice loading indicator while waiting for the first LLM token
- Seamlessly transition to streaming text
- Zero impact on existing code (defaults to false)

## Features shown:
- Markdown rendering
- Character-by-character animation
- Fade-in effects
- RTL support

Try toggling the loading state with the button below!''';

  @override
  void initState() {
    super.initState();
    // Auto-stop loading after 3 seconds to show transition
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        appBar: AppBar(title: const Text('Shimmer Loading Demo')),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                StreamingTextMarkdown.chatGPT(
                  text: _text,
                  markdownEnabled: true,
                  isLoading: _isLoading,
                  shimmerLineCount: 4,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _isLoading = !_isLoading),
                  icon: Icon(_isLoading ? Icons.hide_source : Icons.visibility),
                  label: Text(_isLoading ? 'Show Text' : 'Show Shimmer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
