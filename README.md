# Flutter Streaming Text Markdown

**Perfect for LLM Applications!** A Flutter package optimized for beautiful AI text streaming with ChatGPT and Claude-style animations.

[![pub package](https://img.shields.io/pub/v/flutter_streaming_text_markdown.svg)](https://pub.dev/packages/flutter_streaming_text_markdown)

## ✨ Features

- 🤖 **LLM Optimized** - Built specifically for ChatGPT, Claude, and AI text streaming
- 🎮 **Programmatic Control** - Pause, resume, skip, and restart animations
- ⚡ **Ready-to-Use Presets** - ChatGPT, Claude, typewriter, and more animation styles
- 📝 **Markdown Support** - Full markdown rendering with streaming animations
- 🌐 **RTL Support** - Comprehensive right-to-left language support
- 🎭 **Multiple Animation Types** - Character-by-character, word-by-word, and chunk-based
- ⏱️ **Real-time Streaming** - Direct `Stream<String>` integration
- 🎯 **Interactive Controls** - Tap-to-skip and programmatic control

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_streaming_text_markdown: ^1.2.0
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
| `text` | `String` | The text content to display |
| `controller` | `StreamingTextController?` | Controller for programmatic control |
| `onComplete` | `VoidCallback?` | Callback when animation completes |
| `typingSpeed` | `Duration` | Speed of typing animation |
| `wordByWord` | `bool` | Whether to animate word by word |
| `chunkSize` | `int` | Number of characters to reveal at once |
| `fadeInEnabled` | `bool` | Enable fade-in animation |
| `fadeInDuration` | `Duration` | Duration of fade-in animation |
| `textDirection` | `TextDirection?` | Text direction (LTR or RTL) |
| `textAlign` | `TextAlign?` | Text alignment |
| `markdownEnabled` | `bool` | Enable markdown rendering |

## Markdown Support

The widget supports common markdown syntax:

- Headers (`#`, `##`, `###`)
- Bold text (`**text**` or `__text__`)
- Italic text (`*text*` or `_text_`)
- Lists (ordered and unordered)
- Line breaks

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
  markdownStyleSheet: MarkdownStyleSheet(
    h1: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
    p: TextStyle(fontSize: 16),
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
        markdownStyleSheet: MarkdownStyleSheet(/* ... */),
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