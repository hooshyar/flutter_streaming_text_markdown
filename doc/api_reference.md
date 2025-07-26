# Flutter Streaming Text Markdown - API Reference

## Main Components

### StreamingTextMarkdown

The primary widget for displaying streaming text with markdown support.

```dart
StreamingTextMarkdown(
  text: String,
  initialText: String,
  styleSheet: MarkdownStyleSheet?,
  theme: StreamingTextTheme?,
  padding: EdgeInsets?,
  autoScroll: bool,
  fadeInEnabled: bool,
  fadeInDuration: Duration,
  fadeInCurve: Curve,
  wordByWord: bool,
  chunkSize: int,
  typingSpeed: Duration,
  textDirection: TextDirection?,
  textAlign: TextAlign?,
  markdownEnabled: bool,
)
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `text` | `String` | required | The markdown text to be displayed |
| `initialText` | `String` | `''` | Initial text to show before animation starts |
| `styleSheet` | `MarkdownStyleSheet?` | `null` | Custom markdown style sheet |
| `theme` | `StreamingTextTheme?` | `null` | Custom theme for the widget |
| `padding` | `EdgeInsets?` | `null` | Padding around the text |
| `autoScroll` | `bool` | `true` | Whether to scroll automatically as text appears |
| `fadeInEnabled` | `bool` | `false` | Enable fade-in animation for each character |
| `fadeInDuration` | `Duration` | `300ms` | Duration of fade-in animation |
| `fadeInCurve` | `Curve` | `Curves.easeOut` | The curve to use for fade-in animation |
| `wordByWord` | `bool` | `false` | Whether to animate word by word |
| `chunkSize` | `int` | `1` | Characters to reveal at once (when not wordByWord) |
| `typingSpeed` | `Duration` | `50ms` | Speed at which each unit appears |
| `textDirection` | `TextDirection?` | `null` | Text direction (LTR or RTL) |
| `textAlign` | `TextAlign?` | `null` | Text alignment |
| `markdownEnabled` | `bool` | `false` | Whether to enable markdown rendering |

### StreamingTextTheme

Theme extension for customizing the appearance of StreamingTextMarkdown widgets.

```dart
StreamingTextTheme({
  TextStyle? textStyle,
  MarkdownStyleSheet? markdownStyleSheet,
  EdgeInsets? defaultPadding,
})
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `textStyle` | `TextStyle?` | `null` | Base text style for the widget |
| `markdownStyleSheet` | `MarkdownStyleSheet?` | `null` | Style sheet for markdown elements |
| `defaultPadding` | `EdgeInsets?` | `null` | Default padding for the widget |

#### Usage with ThemeData

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
)
```

### StreamingText

The core widget that handles text animation and display.

```dart
StreamingText({
  required String text,
  TextStyle? style,
  bool markdownEnabled,
  MarkdownStyleSheet? markdownStyleSheet,
  bool fadeInEnabled,
  Duration fadeInDuration,
  Curve fadeInCurve,
  bool wordByWord,
  int chunkSize,
  Duration typingSpeed,
  TextDirection? textDirection,
  TextAlign? textAlign,
  VoidCallback? onComplete,
  StreamProvider? streamProvider,
})
```

## Extension Methods

### StreamingTextTheme Extensions

```dart
// Get the current StreamingTextTheme from a BuildContext
extension StreamingTextThemeExtension on BuildContext {
  StreamingTextTheme get streamingTextTheme;
}
```

## Interfaces

### StreamProvider

Interface for custom stream providers.

```dart
abstract class StreamProvider {
  Stream<String> provideStream(String text);
}
```

### DefaultStreamProvider

Default implementation of StreamProvider.

```dart
class DefaultStreamProvider implements StreamProvider {
  DefaultStreamProvider({
    required this.typingSpeed,
    this.wordByWord = false,
    this.chunkSize = 1,
  });

  final Duration typingSpeed;
  final bool wordByWord;
  final int chunkSize;

  @override
  Stream<String> provideStream(String text);
}
``` 