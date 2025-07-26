# Flutter Streaming Text Markdown - Usage Guide

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_streaming_text_markdown: ^1.1.0
```

Then run:

```bash
flutter pub get
```

## Basic Usage

Import the package:

```dart
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
```

### Simple Example

```dart
StreamingTextMarkdown(
  text: '# Hello World\nThis is a **simple** example with *markdown* support.',
  typingSpeed: Duration(milliseconds: 50),
)
```

This creates a widget that displays "Hello World" as a heading, followed by a sentence with bold and italic text, with characters appearing one by one at 50ms intervals.

## Advanced Configuration

### Word-by-Word Animation

```dart
StreamingTextMarkdown(
  text: 'This text will appear word by word instead of character by character.',
  wordByWord: true,
  typingSpeed: Duration(milliseconds: 200),
)
```

### With Fade-In Effect

```dart
StreamingTextMarkdown(
  text: 'This text will fade in as it appears.',
  fadeInEnabled: true,
  fadeInDuration: Duration(milliseconds: 300),
  fadeInCurve: Curves.easeInOut,
)
```

### RTL Support

```dart
StreamingTextMarkdown(
  text: 'مرحبا بالعالم! هذا نص بالعربية.',
  textDirection: TextDirection.rtl,
  textAlign: TextAlign.right,
)
```

### Custom Chunk Size

To reveal multiple characters at once:

```dart
StreamingTextMarkdown(
  text: 'This text will appear three characters at a time.',
  chunkSize: 3,
  typingSpeed: Duration(milliseconds: 100),
)
```

## Styling and Theming

### Widget-level Styling

```dart
StreamingTextMarkdown(
  text: '# Custom Styled\nThis text has custom styling.',
  styleSheet: MarkdownStyleSheet(
    h1: TextStyle(color: Colors.blue, fontSize: 24),
    p: TextStyle(color: Colors.black87, fontSize: 16),
  ),
  padding: EdgeInsets.all(20),
)
```

### Using Theme Extension

Define a custom theme:

```dart
final customTheme = StreamingTextTheme(
  textStyle: TextStyle(
    fontSize: 16,
    color: Colors.grey[800],
    height: 1.5,
  ),
  markdownStyleSheet: MarkdownStyleSheet(
    h1: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
    h2: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.blue[700]),
    strong: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
    em: TextStyle(fontStyle: FontStyle.italic, color: Colors.green),
  ),
  defaultPadding: EdgeInsets.all(16),
);
```

Apply to a single widget:

```dart
StreamingTextMarkdown(
  text: '# Themed Content\nThis uses a **custom theme** with *styled* elements.',
  theme: customTheme,
)
```

### App-wide Theming

Apply the theme to your entire app:

```dart
MaterialApp(
  theme: ThemeData(
    extensions: [
      StreamingTextTheme(
        textStyle: TextStyle(/* ... */),
        markdownStyleSheet: MarkdownStyleSheet(/* ... */),
      ),
    ],
  ),
  home: MyHomePage(),
)
```

## Integration Examples

### Chat Bubbles

```dart
Container(
  decoration: BoxDecoration(
    color: Colors.blue[100],
    borderRadius: BorderRadius.circular(12),
  ),
  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
  child: StreamingTextMarkdown(
    text: 'This is a message in a **chat bubble** with *formatting*.',
    padding: EdgeInsets.all(12),
    wordByWord: true,
    typingSpeed: Duration(milliseconds: 150),
  ),
)
```

### AI Assistant Response

```dart
StreamingTextMarkdown(
  text: '''# Welcome to AI Assistant
  
I can help you with:
* Writing code
* Answering questions
* **Formatting** text with *markdown*

What would you like to know?''',
  fadeInEnabled: true,
  typingSpeed: Duration(milliseconds: 30),
  padding: EdgeInsets.all(16),
)
```

## Tips and Best Practices

1. **Performance Considerations**
   - For very long text, consider splitting into multiple widgets or implementing lazy loading.
   - Adjust typing speed based on text length (slower for short text, faster for long text).

2. **UX Guidelines**
   - Provide a way for users to skip animations (e.g., tap to complete).
   - Use different animation speeds for different content types.
   - Consider accessibility implications of animated text.

3. **Markdown Usage**
   - The package supports standard markdown syntax through flutter_markdown.
   - Complex markdown features like tables may have limitations with animation.
   - Use markdown judiciously for better readability. 