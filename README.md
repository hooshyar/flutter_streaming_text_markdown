# Flutter Streaming Text Markdown

**Perfect for LLM Applications!** A Flutter package optimized for beautiful AI text streaming with ChatGPT and Claude-style animations.

[![pub package](https://img.shields.io/pub/v/flutter_streaming_text_markdown.svg)](https://pub.dev/packages/flutter_streaming_text_markdown)

## 🆕 v1.9.0 — `StreamingTextMarkdown` now takes a `Stream<String>`
- ✅ **New**: `stream:` parameter on `StreamingTextMarkdown` and every preset (`.chatGPT()`, `.claude()`, `.typewriter()`, `.instant()`, `.fromPreset()`). Pass an LLM token stream directly — no need to drop down to the lower-level `StreamingText`.
- ✅ `text:` is now optional (defaults to `''`). Existing code is unchanged.
- ✅ Per-character fade-in auto-suppressed for streams; use `trailingFadeEnabled` for a smooth reveal.
- ✅ **Still here from v1.8**: `components` / `inlineComponents` for full block- and inline-level markdown overrides, plus `imageBuilder`, `onLinkTap`, `codeBuilder`, `latexBuilder`, `linkBuilder`.
- ✅ **Quality**: tests + analysis green, 160/160 pub.dev score targeted.

## ✨ Features

- 🤖 **LLM Optimized** - Built specifically for ChatGPT, Claude, and AI text streaming
- 🎮 **Programmatic Control** - Pause, resume, skip, and restart animations
- ⚡ **Ready-to-Use Presets** - ChatGPT, Claude, typewriter, and more animation styles
- 📝 **Markdown Support** - Full markdown rendering with streaming animations
- 🔢 **LaTeX Support** - Mathematical expressions and formulas with proper rendering
- 🌐 **RTL Support** - Comprehensive right-to-left language support
- 🎭 **Multiple Animation Types** - Character-by-character, word-by-word, and chunk-based
- ⏱️ **Real-time Streaming** - Direct `Stream<String>` integration
- 🎯 **Interactive Controls** - Tap-to-skip and programmatic control

## 🎬 Demo

The example app showcases all features across multiple tabs:

| Tab | Description |
|-----|-------------|
| **ChatGPT Style** | Fast character-by-character streaming with fade |
| **Claude Style** | Smooth word-by-word animation |
| **LaTeX Demo** | Mathematical equations with inline & block LaTeX |
| **RTL Support** | Arabic text with right-to-left streaming |
| **Controller** | Pause, resume, skip, and speed controls |

> 📹 **Demo video coming soon!** Run the example app yourself: `cd example && flutter run`

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_streaming_text_markdown: ^1.9.0
```

## 🚀 Quick Start

### ChatGPT-Style Streaming

```dart
StreamingTextMarkdown.chatGPT(
  text: '''# Flutter Development Tips

**1. State Management**
- Use **Provider** for simple apps  
- **Riverpod** for complex state
- **BLoC** for enterprise applications

**2. Performance**
- Use `const` constructors
- Implement `ListView.builder` for long lists
- Avoid unnecessary widget rebuilds''',
)
```

### Claude-Style Streaming

```dart
StreamingTextMarkdown.claude(
  text: '''# Understanding Flutter Architecture

I'd be happy to explain Flutter's widget tree and how it impacts performance.

## Widget Tree Fundamentals

Flutter's architecture revolves around three core trees:
- **Widget Tree**: Configuration and description
- **Element Tree**: Lifecycle management  
- **Render Tree**: Layout and painting

This separation enables Flutter's excellent performance...''',
)
```

### Programmatic Control

```dart
final controller = StreamingTextController();

StreamingTextMarkdown.claude(
  text: llmResponse,
  controller: controller,
  onComplete: () => print('Streaming complete!'),
)

// Control the animation
ElevatedButton(
  onPressed: controller.isAnimating ? controller.pause : controller.resume,
  child: Text(controller.isAnimating ? 'Pause' : 'Resume'),
)

ElevatedButton(
  onPressed: controller.skipToEnd,
  child: Text('Skip to End'),
)
```

## 🤖 Streaming from an LLM API (OpenAI, Anthropic, Ollama, …)

For real LLM chat UIs where tokens arrive over HTTP/SSE, pass a `Stream<String>` straight into `StreamingTextMarkdown`. Each yielded chunk is appended to the rendered text and animated. Markdown and LaTeX are re-parsed as the buffer grows.

```dart
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

StreamingTextMarkdown(
  stream: chatService.streamReply(prompt),     // your Stream<String>
  markdownEnabled: true,
  latexEnabled: true,
  trailingFadeEnabled: true,                    // recommended for streams
  typingSpeed: const Duration(milliseconds: 15),
  onComplete: () => setState(() => _isStreaming = false),
)
```

> The preset constructors (`StreamingTextMarkdown.chatGPT(stream: ...)`, `.claude(stream: ...)`, etc.) accept `stream:` too. If you need lower-level control (no auto-scroll, no shimmer, no theme resolution), the underlying `StreamingText` widget is also exported.

### TTFT shimmer (Time-To-First-Token)

Show a skeleton while you wait for the first token, then swap to the streamed widget:

```dart
StreamingTextMarkdown(
  text: _buffer,
  isLoading: _waitingForFirstToken,   // shimmer while true
  trailingFadeEnabled: true,
)
```

### Bridging OpenAI / Anthropic SSE to `Stream<String>`

Most LLM HTTP APIs return Server-Sent Events. Convert their token stream to a plain `Stream<String>` of text deltas — then hand it to `StreamingText`.

```dart
// OpenAI chat completions (stream: true) — yield content deltas
Stream<String> openAiChat(String prompt) async* {
  final req = http.Request('POST', Uri.parse('https://api.openai.com/v1/chat/completions'))
    ..headers.addAll({
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    })
    ..body = jsonEncode({
      'model': 'gpt-4o-mini',
      'stream': true,
      'messages': [{'role': 'user', 'content': prompt}],
    });
  final res = await http.Client().send(req);
  await for (final line in res.stream.transform(utf8.decoder).transform(const LineSplitter())) {
    if (!line.startsWith('data: ')) continue;
    final payload = line.substring(6);
    if (payload == '[DONE]') break;
    final delta = (jsonDecode(payload)['choices'][0]['delta']['content']) as String?;
    if (delta != null && delta.isNotEmpty) yield delta;
  }
}
```

```dart
// Anthropic Messages API (stream: true) — yield content_block_delta text
Stream<String> anthropicChat(String prompt) async* {
  final req = http.Request('POST', Uri.parse('https://api.anthropic.com/v1/messages'))
    ..headers.addAll({
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    })
    ..body = jsonEncode({
      'model': 'claude-sonnet-4-5',
      'max_tokens': 1024,
      'stream': true,
      'messages': [{'role': 'user', 'content': prompt}],
    });
  final res = await http.Client().send(req);
  await for (final line in res.stream.transform(utf8.decoder).transform(const LineSplitter())) {
    if (!line.startsWith('data: ')) continue;
    final json = jsonDecode(line.substring(6));
    if (json['type'] == 'content_block_delta') {
      final text = json['delta']?['text'] as String?;
      if (text != null && text.isNotEmpty) yield text;
    }
  }
}
```

> ⚠️ **Choose `trailingFadeEnabled` over `fadeInEnabled` for streams.** Per-character fades spawn one `AnimationController` per glyph — fine for static text, but unbounded streams will exhaust memory. The widget auto-disables `fadeInEnabled` when a `stream` is set; `trailingFadeEnabled` gives you a smooth gradient reveal with constant memory.

### When to use which widget

| Use case | Widget |
|----------|--------|
| Default — static `String` **or** `Stream<String>` with auto-scroll, theme, and TTFT shimmer | `StreamingTextMarkdown` (or its `.chatGPT/.claude/.typewriter/.instant` presets) |
| Lower-level control — no auto-scroll, no shimmer, no theme inheritance | `StreamingText` |

Both widgets accept the same `text:` / `stream:` pair. Pick `StreamingTextMarkdown` unless you need to opt out of the convenience scaffolding.

## 🎨 Animation Presets

### Built-in Constructors

| Constructor | Speed | Style | Best For |
|-------------|-------|--------|----------|
| `.chatGPT()` | Fast (15ms) | Character-by-character with fade | ChatGPT-like responses |
| `.claude()` | Smooth (80ms) | Word-by-word with gentle fade | Claude-like detailed explanations |
| `.typewriter()` | Classic (50ms) | Character-by-character, no fade | Retro typewriter effect |
| `.instant()` | Immediate | No animation | When speed is priority |

### Custom Presets

```dart
// Using preset configurations
StreamingTextMarkdown.fromPreset(
  text: response,
  preset: LLMAnimationPresets.professional,
)

// Available presets
LLMAnimationPresets.chatGPT       // Fast, character-based
LLMAnimationPresets.claude        // Smooth, word-based  
LLMAnimationPresets.typewriter    // Classic typing
LLMAnimationPresets.gentle        // Slow, elegant
LLMAnimationPresets.bouncy        // Playful bounce effect
LLMAnimationPresets.chunks        // Fast chunk-based
LLMAnimationPresets.rtlOptimized  // Optimized for Arabic/RTL
LLMAnimationPresets.professional  // Business presentations

// Speed-based presets
LLMAnimationPresets.bySpeed(AnimationSpeed.fast)
LLMAnimationPresets.bySpeed(AnimationSpeed.medium)
LLMAnimationPresets.bySpeed(AnimationSpeed.slow)
```

## 🎮 Controller API

```dart
final controller = StreamingTextController();

// Control methods
controller.pause();          // Pause animation
controller.resume();         // Resume from pause
controller.restart();        // Start over
controller.skipToEnd();      // Jump to end
controller.stop();           // Stop and reset

// State monitoring
controller.isAnimating;      // Currently running?
controller.isPaused;         // Currently paused?
controller.isCompleted;      // Animation finished?
controller.progress;         // Progress (0.0 to 1.0)
controller.state;            // Current state enum

// Callbacks
controller.onStateChanged((state) => print('State: $state'));
controller.onProgressChanged((progress) => print('Progress: $progress'));
controller.onCompleted(() => print('Finished!'));

// Speed control
controller.speedMultiplier = 2.0;  // 2x speed
controller.speedMultiplier = 0.5;  // Half speed
```

## ⚙️ Configuration

### StreamingTextMarkdown Parameters

| Property | Type | Description |
|----------|------|-------------|
| `text` | `String` | The text content to display. Optional — defaults to `''` so you can pass only `stream:` when streaming from an LLM. |
| `stream` | `Stream<String>?` | Optional stream of text chunks from an LLM API. When non-null, content arrives via the stream and per-character fade-in is auto-suppressed (use `trailingFadeEnabled`). |
| `controller` | `StreamingTextController?` | Controller for programmatic control |
| `onComplete` | `VoidCallback?` | Callback when animation completes |
| `completeAnimationOnTap` | `bool` | Whether tapping the widget jumps the animation to completion. Defaults to `true`; set `false` to let it play through regardless of taps. |
| `typingSpeed` | `Duration` | Speed of typing animation |
| `wordByWord` | `bool` | Whether to animate word by word |
| `chunkSize` | `int` | Number of characters to reveal at once |
| `fadeInEnabled` | `bool` | Per-character fade-in. Auto-disabled for Arabic/RTL and for `Stream<String>` sources — use `trailingFadeEnabled` for streams. |
| `fadeInDuration` | `Duration` | Duration of fade-in animation (also used for trailing-fade dismiss) |
| `trailingFadeEnabled` | `bool` | Bottom-edge gradient fade while streaming. Animates away on completion. Recommended for `Stream<String>` and markdown content. |
| `textDirection` | `TextDirection?` | Text direction (LTR or RTL) |
| `textAlign` | `TextAlign?` | Text alignment |
| `markdownEnabled` | `bool` | Enable markdown rendering |
| `latexEnabled` | `bool` | Enable LaTeX mathematical expressions |
| `latexStyle` | `TextStyle?` | Style for LaTeX expressions |
| `latexScale` | `double` | Scale factor for LaTeX rendering |
| `latexFadeInEnabled` | `bool?` | Enable fade-in for LaTeX (null = auto) |
| `imageBuilder` | `Widget Function(BuildContext, String)?` | Custom widget for markdown images |
| `onLinkTap` | `void Function(String url, String title)?` | Callback when a link is tapped |
| `codeBuilder` | `Widget Function(BuildContext, String name, String code, bool closed)?` | Custom widget for code blocks |
| `latexBuilder` | `Widget Function(BuildContext, String tex, TextStyle, bool inline)?` | Custom widget for LaTeX expressions |
| `linkBuilder` | `Widget Function(BuildContext, InlineSpan label, String path, TextStyle)?` | Custom widget for links |
| `components` | `List<MarkdownComponent>?` | Block-level component overrides — headers, lists, code blocks, tables, blockquotes. `null` keeps `gpt_markdown` defaults. |
| `inlineComponents` | `List<MarkdownComponent>?` | Inline-level component overrides — bold, italic, strikethrough, links, inline code. `null` keeps `gpt_markdown` defaults. |

#### Choosing a fade for streaming content

| Source | Recommended | Why |
|--------|-------------|-----|
| Static `text` (LTR) | `fadeInEnabled: true` | Cheap per-character fade, looks great |
| Static `text` (Arabic/RTL) | `trailingFadeEnabled: true` | Per-character fade auto-disabled for RTL |
| `Stream<String>` | `trailingFadeEnabled: true` | Per-character fade auto-disabled to avoid an unbounded number of `AnimationController`s |

## Markdown Support

The widget supports common markdown syntax:

- Headers (`#`, `##`, `###`)
- Bold text (`**text**` or `__text__`)
- Italic text (`*text*` or `_text_`)
- Lists (ordered and unordered)
- Line breaks

## 🔢 LaTeX Support

The package includes comprehensive LaTeX support for mathematical expressions and formulas, perfect for educational content, scientific documentation, and technical explanations.

### Basic LaTeX Usage

```dart
StreamingTextMarkdown(
  text: '''# Mathematical Equations

Inline equations work great: \$E = mc^2\$ and \$x = 5\$.

Block equations are perfect for complex formulas:
\$\$x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}\$\$

This is the quadratic formula!''',
  latexEnabled: true,
  markdownEnabled: true,
)
```

### LaTeX Configuration

```dart
StreamingTextMarkdown(
  text: 'Mathematical content with \$x^2 + y^2 = z^2\$',
  latexEnabled: true,              // Enable LaTeX rendering
  latexStyle: TextStyle(           // Style for LaTeX expressions
    color: Colors.blue,
    fontSize: 18,
  ),
  latexScale: 1.2,                 // Scale factor for LaTeX
  latexFadeInEnabled: false,       // Disable fade-in for LaTeX (recommended)
  markdownEnabled: true,
)
```

### LaTeX Theme Support

```dart
// Global LaTeX styling through theme
final customTheme = StreamingTextTheme(
  inlineLatexStyle: TextStyle(color: Colors.blue),
  blockLatexStyle: TextStyle(color: Colors.purple),
  latexScale: 1.3,
  latexFadeInEnabled: false,
);

StreamingTextMarkdown(
  text: 'Themed math: \$\\alpha + \\beta = \\gamma\$',
  theme: customTheme,
  latexEnabled: true,
)
```

### Supported LaTeX Features

**Inline Math**: `$x = 5$`, `$E = mc^2$`, `$\alpha + \beta$`

**Block Math**: 
```latex
$$\sum_{i=1}^{n} i = \frac{n(n+1)}{2}$$
```

**Common Symbols**:
- Greek letters: `\alpha`, `\beta`, `\gamma`, `\pi`, `\sigma`
- Operations: `\pm`, `\cdot`, `\times`, `\div`, `\neq`
- Relations: `\leq`, `\geq`, `\approx`, `\equiv`
- Fractions: `\frac{a}{b}`
- Powers: `x^2`, `a^{n+1}`
- Subscripts: `x_1`, `a_{i,j}`
- Roots: `\sqrt{x}`, `\sqrt[3]{x}`

**Advanced Features**:
- Integrals: `\int_0^1 x dx`
- Summations: `\sum_{i=1}^n x_i`
- Matrices: `\begin{matrix} a & b \\ c & d \end{matrix}`
- Derivatives: `\frac{d}{dx}[f(x)]`

### LaTeX Animation Behavior

- LaTeX expressions are treated as **atomic units** during streaming
- They appear completely when their turn comes in the animation
- Fade-in effects can be disabled for LaTeX for better performance
- Works seamlessly with word-by-word and character-by-character modes

### Performance Tips

1. **Disable fade-in for LaTeX**: Set `latexFadeInEnabled: false` for better performance
2. **Cache complex expressions**: LaTeX rendering is automatically optimized
3. **Mix with regular text**: Combine LaTeX with markdown for rich content

### Example: Scientific Documentation

```dart
StreamingTextMarkdown.claude(
  text: '''# Physics Fundamentals

## Newton's Laws

Newton's second law states that force equals mass times acceleration:
\$\$F = ma\$\$

## Energy Conservation

The relationship between kinetic and potential energy:
\$\$KE + PE = \\text{constant}\$\$

Where kinetic energy is \$KE = \\frac{1}{2}mv^2\$ and potential energy varies by system.

## Wave Equation

The fundamental wave equation in physics:
\$\$\\frac{\\partial^2 y}{\\partial t^2} = \\frac{1}{v^2}\\frac{\\partial^2 y}{\\partial x^2}\$\$

This describes how waves propagate through different media.''',
  latexEnabled: true,
)
```

## RTL Support

For right-to-left languages:

```dart
StreamingTextMarkdown(
  text: '''# مرحباً بكم! 👋
هذا **عرض توضيحي** للنص المتدفق.''',
  textDirection: TextDirection.rtl,
  textAlign: TextAlign.right,
)
```

## Styling and Theming

### Using the Theme System

The package now supports a professional theme system that allows you to customize both normal text and markdown styling:

```dart
// Create a custom theme
final customTheme = StreamingTextTheme(
  textStyle: TextStyle(fontSize: 16, color: Colors.blue),
  markdownStyleSheet: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: Colors.black87,
  ),
  defaultPadding: EdgeInsets.all(20),
);

// Apply theme to a single widget
StreamingTextMarkdown(
  text: '# Hello\nThis is a test',
  theme: customTheme,
)

// Or apply globally through your app's theme
MaterialApp(
  theme: ThemeData(
    extensions: [
      StreamingTextTheme(
        textStyle: TextStyle(/* ... */),
        markdownStyleSheet: TextStyle(/* ... */),
      ),
    ],
  ),
  // ...
)
```

### Theme Inheritance

The theme system follows Flutter's standard inheritance pattern:
1. Widget-level theme (if provided)
2. Global theme extension
3. Default theme based on the current context

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details. 