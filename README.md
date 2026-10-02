# Flutter Streaming Text Markdown

**Perfect for LLM Applications!** A Flutter package optimized for beautiful AI text streaming with ChatGPT and Claude-style animations.

[![pub package](https://img.shields.io/pub/v/flutter_streaming_text_markdown.svg)](https://pub.dev/packages/flutter_streaming_text_markdown)
[![CI](https://github.com/hooshyar/flutter_streaming_text_markdown/actions/workflows/ci.yml/badge.svg)](https://github.com/hooshyar/flutter_streaming_text_markdown/actions/workflows/ci.yml)
[![pub points](https://img.shields.io/pub/points/flutter_streaming_text_markdown)](https://pub.dev/packages/flutter_streaming_text_markdown/score)
[![likes](https://img.shields.io/pub/likes/flutter_streaming_text_markdown)](https://pub.dev/packages/flutter_streaming_text_markdown/score)
[![downloads](https://img.shields.io/pub/dm/flutter_streaming_text_markdown)](https://pub.dev/packages/flutter_streaming_text_markdown/score)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/hooshyar/flutter_streaming_text_markdown/blob/main/LICENSE)

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
- ♿ **Accessibility** - Reduced-motion support, single-announcement semantics, and selectable text
- ⚠️ **Stream error handling** - `errorBuilder` plus a controller error state, with revealed text kept on screen

## 🎬 Demo

<img src="https://raw.githubusercontent.com/hooshyar/flutter_streaming_text_markdown/main/doc/demo.gif" alt="The 1.11.0 example app: streaming markdown, presets, and the animation controller" width="720"/>

Full-quality video: [doc/demo.mp4](https://github.com/hooshyar/flutter_streaming_text_markdown/raw/main/doc/demo.mp4)

▶️ **[Try the live web demo](https://hooshyar.github.io/flutter_streaming_text_markdown/)** — or run it locally: `cd example && flutter run`

The example app walks through every feature: presets (ChatGPT / Claude / typewriter), live `Stream<String>` input, markdown & LaTeX rendering, RTL/Arabic, theming, and the animation controller.

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_streaming_text_markdown: ^1.11.0
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
  onComplete: () => setState(() => _isStreaming = false),
)
```

> `stream:` input defaults to `RevealMode.smoothFade` (word-unit reveal + fade)
> paced by `StreamPacing.catchUp()` (smooths bursty token arrivals instead of
> a fixed `typingSpeed`) — `typingSpeed` has no effect on stream input unless
> you pass `revealMode: null` or an explicit `pacing: StreamPacing.fixed(...)`.
> See [Configuration](#%EF%B8%8F-configuration) below.

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

### Handling stream errors

If the `Stream<String>` you pass emits an error, the text revealed so far
stays on screen either way. Pass `errorBuilder` to render your own view; the
`controller` (if any) also transitions to `StreamingTextState.error` via
`markError`, and `controller.error` exposes the error object:

```dart
StreamingTextMarkdown(
  stream: chatService.streamReply(prompt),
  controller: controller,
  errorBuilder: (context, error) => Row(
    children: [
      const Icon(Icons.error_outline),
      const SizedBox(width: 8),
      Expanded(child: Text('Something went wrong: $error')),
    ],
  ),
)
```

Without an `errorBuilder`, the default view shows the text revealed so far
plus a trailing `Error: $error` line in `Theme.of(context).colorScheme.error`.

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

> `fadeInEnabled` is safe for streams too: the per-character fade is driven
> by a single `Ticker` (not one `AnimationController` per glyph), so it has
> constant memory regardless of stream length. It only applies in
> plain-text mode though; markdown content (the common case for LLM
> output) already gets a paint-only per-word fade via `MarkdownFadeMask`
> in the default `smoothFade`/`wordFade` reveal modes, and
> `trailingFadeEnabled` can add a bottom-edge gradient on top.

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

// Speed control — divides typingSpeed, so higher is faster
controller.speedMultiplier = 2.0;  // 2x speed (half the typingSpeed duration)
controller.speedMultiplier = 0.5;  // Half speed (double the typingSpeed duration)

// Error handling — set when a stream's Stream<String> emits an error
controller.markError(someError);
controller.error;            // The Object passed to markError, or null
```

`onCompleted` fires **at most once** per revealing→complete transition,
however it was triggered — `updateProgress(1.0)`, `markCompleted()`, and
`skipToEnd()` all route through the same completion latch, so wiring more
than one of them (or calling one twice) never double-fires your callback.
`restart()`/`stop()` re-arm it for the next cycle.

## ⚙️ Configuration

### StreamingTextMarkdown Parameters

| Property | Type | Description |
|----------|------|-------------|
| `text` | `String` | The text content to display. Optional — defaults to `''` so you can pass only `stream:` when streaming from an LLM. |
| `stream` | `Stream<String>?` | Optional stream of text chunks from an LLM API. When non-null, content arrives via the stream instead of `text`. |
| `controller` | `StreamingTextController?` | Controller for programmatic control |
| `onComplete` | `VoidCallback?` | Callback when animation completes |
| `completeAnimationOnTap` | `bool` | Whether tapping the widget jumps the animation to completion. Defaults to `true`; set `false` to let it play through regardless of taps. |
| `revealMode` | `RevealMode?` | How revealed text arrives on screen: `{smoothFade, wordFade, typewriter, instant}`. Defaults to `RevealMode.smoothFade` on this constructor, `.chatGPT()` and `.claude()`; `.typewriter()`/`.instant()` default to their own matching mode. Pass `revealMode: null` to opt out entirely and use the legacy `typingSpeed`/`wordByWord`/`fadeInEnabled`/`fadeInDuration`/`fadeInCurve`/`chunkSize` parameters below instead — see `doc/MIGRATION.md`. |
| `pacing` | `StreamPacing?` | How a `Stream<String>` (or static `text`) source is paced: `StreamPacing.catchUp(...)` (the default for `stream:`, smoothing bursty token arrivals) or `StreamPacing.fixed(typingSpeed)` (the default for static `text`, and the pre-2.0 behavior). An explicit value always overrides the default. |
| `typingSpeed` | `Duration` | Speed of typing animation. Only meaningful with `revealMode: null`, `.typewriter()`, or an explicit `StreamPacing.fixed(...)`. |
| `wordByWord` | `bool` | Whether to animate word by word. Ignored unless `revealMode: null` (`smoothFade`/`wordFade` always reveal word-by-word; `.typewriter()`/`.instant()` always reveal by `chunkSize`). |
| `chunkSize` | `int` | Number of characters to reveal at once. Ignored in word-unit modes. |
| `fadeInEnabled` | `bool` | Legacy per-character fade-in, opacity-only, driven by a single `Ticker` (constant memory). Only applies in plain-text mode (`markdownEnabled: false`), only takes effect with `revealMode: null`, and is suppressed for Arabic/RTL. Use `revealMode: RevealMode.smoothFade` (the default) for a fade that also covers Arabic and markdown content (markdown fades paint-only, per word, via `MarkdownFadeMask`). |
| `fadeInDuration` | `Duration` | Duration of fade-in animation (also used for trailing-fade dismiss) |
| `trailingFadeEnabled` | `bool` | Bottom-edge gradient fade while streaming. Animates away on completion. Recommended for `Stream<String>` and markdown content. |
| `textDirection` | `TextDirection?` | Text direction (LTR or RTL) |
| `textAlign` | `TextAlign?` | Text alignment |
| `markdownEnabled` | `bool` | Enable markdown rendering |
| `latexEnabled` | `bool` | Enable LaTeX mathematical expressions |
| `latexStyle` | `TextStyle?` | Style for LaTeX expressions |
| `latexScale` | `double` | Scale factor for LaTeX rendering |
| `latexFadeInEnabled` | `bool?` | **Deprecated**, no-op. LaTeX rendering is delegated to `gpt_markdown`, which has no per-run fade hook; use `latexBuilder` instead. |
| `imageBuilder` | `Widget Function(BuildContext, String)?` | Custom widget for markdown images |
| `onLinkTap` | `void Function(String url, String title)?` | Callback when a link is tapped |
| `codeBuilder` | `Widget Function(BuildContext, String name, String code, bool closed)?` | Custom widget for code blocks |
| `latexBuilder` | `Widget Function(BuildContext, String tex, TextStyle, bool inline)?` | Custom widget for LaTeX expressions |
| `linkBuilder` | `Widget Function(BuildContext, InlineSpan label, String path, TextStyle)?` | Custom widget for links |
| `components` | `List<MarkdownComponent>?` | **Deprecated** — use `markdownOptions.blockComponents`. Block-level component overrides. Passing this at all (even an empty list) drops `gpt_markdown`'s incremental segment cache. |
| `inlineComponents` | `List<MarkdownComponent>?` | **Deprecated** — use `markdownOptions.inlinePatterns`. Inline-level component overrides, with the same segment-cache cost as `components`. |
| `markdownOptions` | `MarkdownRenderOptions?` | Bundles every `gpt_markdown` 1.3 pass-through without its own top-level parameter — see [MarkdownRenderOptions](#-markdownrenderoptions) below. |
| `selectable` | `bool` | Wraps the rendered output in a `SelectionArea` so users can select/copy text. Defaults to `false`. Tap-to-complete still works. |
| `showCursor` | `bool?` | Shows an 8px pulsing dot caret while revealing. `null` (default) resolves to `stream != null` — on for live streams, off for static text. Hidden automatically on completion. |
| `cursorColor` | `Color?` | Color of the caret shown while `showCursor` resolves to `true`. Defaults to the theme's text-primary token. |
| `semanticsLabel` | `String?` | Accessibility label announced/exposed to assistive technology instead of the revealed text itself — see [Accessibility](#-accessibility) below. |
| `errorBuilder` | `Widget Function(BuildContext, Object error)?` | Called when `stream` emits an error — see [Handling stream errors](#handling-stream-errors) below. |

#### Choosing a fade for streaming content

The default `revealMode: RevealMode.smoothFade` already fades plain text,
`Stream<String>` input, markdown content, AND Arabic/RTL content. Plain
text fades via a single `Ticker` regardless of how much text there is (at
most 2 transient tickers); markdown content gets a paint-only per-word
fade via `MarkdownFadeMask` with no `GptMarkdown` rebuilds (disabled
under reduced motion or when `animationsEnabled` is `false`). The table
below compares the defaults with the legacy (`revealMode: null`) fade
parameters:

| Source | Recommended | Why |
|--------|-------------|-----|
| Static or streamed `text`, markdown off | `revealMode: RevealMode.smoothFade` (default) or `fadeInEnabled: true` with `revealMode: null` | Single-ticker fade, looks great |
| Arabic/RTL content | `revealMode: RevealMode.smoothFade` (default) | The legacy `fadeInEnabled` (`revealMode: null`) is suppressed for Arabic (shaping risk); `smoothFade` isn't |
| Markdown-enabled content | `revealMode: RevealMode.smoothFade` (default) | `MarkdownFadeMask` applies a paint-only per-word fade by default; add `trailingFadeEnabled: true` for a bottom-edge gradient on top |

## Markdown Support

The widget supports common markdown syntax:

- Headers (`#`, `##`, `###`)
- Bold text (`**text**` or `__text__`)
- Italic text (`*text*` or `_text_`)
- Lists (ordered and unordered)
- Line breaks

## 🧩 MarkdownRenderOptions

`components` / `inlineComponents` are deprecated because passing either one
(even an empty list) drops `gpt_markdown`'s incremental segment cache.
`markdownOptions` bundles every other `gpt_markdown` 1.3 pass-through — style
sheet, per-component builders, autolink config, and more — without that
cost:

```dart
StreamingTextMarkdown(
  text: llmResponse,
  markdownOptions: MarkdownRenderOptions(
    styleSheet: GptMarkdownStyleSheet(
      inlineCode: InlineCodeStyle(color: Colors.deepPurple),
    ),
    autolink: true,
    maxLines: 200,
    // Recolour link labels without changing anything else about how
    // links render — see LinkBuildDetails.defaultSpan/.asWidgetSpan.
    inlineLinkBuilder: (link) => link.defaultSpan(),
  ),
)
```

Every field maps 1:1 onto a `GptMarkdown` constructor parameter of the same
name; a `null` field simply falls back to `gpt_markdown`'s own default. See
the class docs on `MarkdownRenderOptions` for the full field list —
`styleSheet`, `inlineCodeStyle`, the block-level builders (`headingBuilder`,
`tableBuilder`, `blockQuoteBuilder`, `orderedListBuilder`,
`unOrderedListBuilder`, `hrBuilder`, `checkboxBuilder`,
`radioOptionBuilder`), the `on*` callbacks, `autolink`/`autolinkSchemes`,
`maxLines`/`overflow`/`followLinkColor`, `blockComponents`/`inlinePatterns`/
`inlineDirectives`, the `inline*Builder`s, `imageBuilder`, and
`useDollarSignsForLatex`.

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
  markdownEnabled: true,
)
```

> `latexFadeInEnabled` (both the widget parameter and
> `StreamingTextTheme.latexFadeInEnabled`) is deprecated and now a no-op —
> LaTeX rendering is delegated to `gpt_markdown`, which has no per-run fade
> hook of its own. Use a `latexBuilder` if you need to control LaTeX
> rendering directly.

### LaTeX Theme Support

```dart
// Global LaTeX styling through theme
final customTheme = StreamingTextTheme(
  inlineLatexStyle: TextStyle(color: Colors.blue),
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

- LaTeX expressions are treated as **atomic units** during streaming — the
  cursor never lands strictly inside a `$…$`/`$$…$$`/`\(…\)`/`\[…\]` span
- They appear completely when their turn comes in the animation
- Per-run fade is suppressed for LaTeX spans by default for performance
- Works seamlessly with word-by-word and character-by-character modes

### Performance Tips

1. **Mix with regular text**: Combine LaTeX with markdown for rich content
2. **`$VARS`-style text in code fences is safe**: content inside fenced or
   inline code is never mistaken for LaTeX, even when it looks like a
   dollar-sign variable

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

## ♿ Accessibility

```dart
StreamingTextMarkdown(
  stream: chatService.streamReply(prompt),
  semanticsLabel: 'Assistant response',
  selectable: true,
)
```

- **Reduced motion**: when the platform's reduce-motion setting is on
  (`MediaQuery.maybeDisableAnimationsOf`), text reveals instantly with a
  static caret and no fade — no extra configuration needed.
- **Semantics**: partial, mid-stream text is excluded from the accessibility
  tree, and assistive technology gets exactly one announcement — of the
  full revealed text, or of `semanticsLabel` when you set one — on
  completion.
- **Selectable text**: `selectable: true` wraps the rendered output in a
  `SelectionArea`. Tap-to-complete keeps working alongside it.
- **Caret**: `showCursor` (`null` by default, resolving to `stream != null`)
  shows an 8px pulsing dot while revealing, styled by `cursorColor` (falls
  back to the theme's text-primary token) and hidden automatically once
  complete, so the final text always matches the source exactly — including
  in markdown mode.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details. 