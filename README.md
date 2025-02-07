# Flutter Streaming Text Markdown

A Flutter package that provides a customizable widget for displaying text and markdown content with typing animation effects.

[![pub package](https://img.shields.io/pub/v/flutter_streaming_text_markdown.svg)](https://pub.dev/packages/flutter_streaming_text_markdown)

## Features

- 📝 Supports both plain text and markdown content
- ⌨️ Customizable typing animation
- 🎭 Word-by-word or character-by-character typing
- ✨ Fade-in animation effects
- 🌐 RTL (Right-to-Left) language support
- 📱 Responsive and customizable design
- 🎯 Interactive tap-to-complete feature (skip animation)

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_streaming_text_markdown: ^1.0.1
```

## Usage

### Basic Example

```dart
StreamingTextMarkdown(
  text: '''# Welcome! 👋
This is a **demo** of streaming text with *markdown* support.''',
  typingSpeed: Duration(milliseconds: 50),
  fadeInEnabled: true,
)
```

### Advanced Example

```dart
StreamingTextMarkdown(
  text: markdownText,
  initialText: 'Loading...\n\n',
  fadeInEnabled: true,
  fadeInDuration: Duration(milliseconds: 300),
  wordByWord: true,
  typingSpeed: Duration(milliseconds: 100),
  textDirection: TextDirection.ltr,
  textAlign: TextAlign.left,
  onComplete: () {
    print('Animation complete!');
  },
)
```

## Configuration

| Property | Type | Description |
|----------|------|-------------|
| `text` | `String` | The text content to display |
| `initialText` | `String?` | Initial text to show before animation starts |
| `typingSpeed` | `Duration` | Speed of typing animation |
| `wordByWord` | `bool` | Whether to animate word by word |
| `chunkSize` | `int` | Number of characters to reveal at once |
| `fadeInEnabled` | `bool` | Enable fade-in animation |
| `fadeInDuration` | `Duration` | Duration of fade-in animation |
| `textDirection` | `TextDirection?` | Text direction (LTR or RTL) |
| `textAlign` | `TextAlign?` | Text alignment |
| `onComplete` | `VoidCallback?` | Callback when animation completes |

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