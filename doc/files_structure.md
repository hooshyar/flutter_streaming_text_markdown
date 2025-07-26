# Flutter Streaming Text Markdown - Files Structure

## Directory Structure

```
flutter_streaming_text_markdown/
├── lib/
│   ├── flutter_streaming_text_markdown.dart  # Main library file and exports
│   └── src/
│       ├── streaming/                        # Core streaming implementation
│       │   ├── streaming.dart                # Exports all streaming components
│       │   ├── streaming_text.dart           # Main widget implementation
│       │   ├── default_stream_provider.dart  # Default text streaming logic
│       │   └── stream_provider.dart          # Stream provider interfaces
│       ├── theme/                            # Theming system
│       │   └── streaming_text_theme.dart     # Theme implementation
│       └── vercel_ai/                        # Vercel AI integration (empty)
├── example/                                  # Example application
│   └── lib/
│       └── main.dart                         # Example usage
├── test/                                     # Unit and widget tests
│   └── flutter_streaming_text_markdown_test.dart
├── README.md                                 # Package documentation
├── CHANGELOG.md                              # Version history
├── pubspec.yaml                              # Package metadata and dependencies
└── LICENSE                                   # MIT License
```

## Key Files Description

### Library Entry Point
- **flutter_streaming_text_markdown.dart**: Main library file that exports all public APIs and includes the `StreamingTextMarkdown` widget implementation.

### Core Implementation
- **streaming_text.dart**: Contains the core `StreamingText` widget that handles text animation and rendering.
- **default_stream_provider.dart**: Implements the default streaming logic for character-by-character and word-by-word animations.
- **stream_provider.dart**: Defines interfaces for custom stream providers.

### Theming System
- **streaming_text_theme.dart**: Implements the `StreamingTextTheme` class that integrates with Flutter's theme extension system.

### Example
- **example/lib/main.dart**: Comprehensive example demonstrating various use cases and configurations.

### Tests
- **flutter_streaming_text_markdown_test.dart**: Widget tests for the core functionality.

## Dependencies

The package has minimal dependencies:
- **flutter_markdown**: For rendering markdown content
- **characters**: For proper Unicode character handling

## File Relationships

1. **User-Facing Components**:
   - `StreamingTextMarkdown` (in flutter_streaming_text_markdown.dart) is the main widget users interact with.
   
2. **Internal Implementation**:
   - `StreamingTextMarkdown` uses `StreamingText` for the core animation and rendering.
   - `StreamingText` uses a stream provider (default or custom) to handle text animation.
   
3. **Styling System**:
   - `StreamingTextTheme` provides theme extension capabilities.
   - Theme data flows from app theme → widget theme → individual component styles. 