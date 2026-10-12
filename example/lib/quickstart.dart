import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

void main() => runApp(const MaterialApp(home: Scaffold(body: ReplyView())));

class ReplyView extends StatefulWidget {
  const ReplyView({super.key});

  @override
  State<ReplyView> createState() => _ReplyViewState();
}

class _ReplyViewState extends State<ReplyView> {
  // Create the stream once, not in build(): a new stream on every rebuild
  // would restart the reply.
  late final Stream<String> _reply = fakeLlmReply();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: StreamingTextMarkdown.claude(stream: _reply),
    );
  }
}

/// Stands in for an LLM: yields a markdown reply one word at a time.
Stream<String> fakeLlmReply() async* {
  const reply = '## Hello!\n\n'
      'This reply **streams in** token by token, with `inline code` '
      'and lists:\n\n'
      '- tokens are appended as they arrive\n'
      '- markdown is re-rendered as it grows\n';
  for (final token in RegExp(r'\S+\s*').allMatches(reply)) {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    yield token[0]!;
  }
}
