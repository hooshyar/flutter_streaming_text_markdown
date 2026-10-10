# flutter_streaming_text_markdown examples

Short recipes for the common cases. To see every feature (presets, live
`Stream<String>` input, markdown, LaTeX, RTL, theming, the controller), open
the [live web demo](https://hooshyar.github.io/flutter_streaming_text_markdown/)
or run this app with `flutter run` from this folder.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
```

## Stream an LLM reply as live markdown

Pass any `Stream<String>` of text chunks: an OpenAI, Anthropic or Gemini SSE
bridge, Ollama, or your own backend. Create the stream once and keep it in
`State`. A new `Stream` instance on every build would re-subscribe and send
a new request each time.

```dart
class Reply extends StatefulWidget {
  const Reply({super.key, required this.prompt});

  final String prompt;

  @override
  State<Reply> createState() => _ReplyState();
}

class _ReplyState extends State<Reply> {
  late final Stream<String> _reply = myLlmClient.streamReply(widget.prompt);

  @override
  Widget build(BuildContext context) {
    return StreamingTextMarkdown(
      stream: _reply,
      markdownEnabled: true,
      latexEnabled: true,
      trailingFadeEnabled: true,
    );
  }
}
```

Half-finished syntax such as `**bol`, an open code fence or a partial table
row is held back until it completes, so raw markers never flash on screen.

## Presets

Presets turn markdown on and pick tuned reveal settings:

```dart
StreamingTextMarkdown.chatGPT(stream: _reply)
StreamingTextMarkdown.claude(stream: _reply)
StreamingTextMarkdown.typewriter(text: 'Hello, world!')
StreamingTextMarkdown.instant(text: alreadyCompleteAnswer)
```

## Waiting for the first token

```dart
StreamingTextMarkdown(
  text: buffer,
  markdownEnabled: true,
  isLoading: waitingForFirstToken, // skeleton shimmer while true
)
```

## Pause, resume and skip

```dart
final controller = StreamingTextController();

StreamingTextMarkdown.claude(text: answer, controller: controller);

controller.pause();
controller.resume();
controller.skipToEnd();
```

## Errors

The text revealed so far stays on screen; `errorBuilder` adds your own view
below it:

```dart
StreamingTextMarkdown(
  stream: _reply,
  markdownEnabled: true,
  errorBuilder: (context, error) => Text('Something went wrong: $error'),
)
```

## Right-to-left text

Arabic-script text (Arabic, Farsi, Kurdish, Urdu) is detected automatically.
Pass `textDirection` for other right-to-left scripts or to force a direction:

```dart
StreamingTextMarkdown(
  text: 'مرحبا بك في **Flutter**',
  markdownEnabled: true,
  textDirection: TextDirection.rtl,
)
```

## Accessibility

Reduced motion is honoured automatically. Partial mid-stream text is kept out
of the accessibility tree and announced once on completion:

```dart
StreamingTextMarkdown(
  stream: _reply,
  markdownEnabled: true,
  semanticsLabel: 'Assistant response',
  selectable: true,
)
```

For a complete chat screen (bubbles, composer, scrolling) built on this
package, see
[`flutter_gen_ai_chat_ui`](https://pub.dev/packages/flutter_gen_ai_chat_ui).
