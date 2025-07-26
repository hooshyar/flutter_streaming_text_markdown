# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Flutter package (`flutter_streaming_text_markdown`) that provides animated text display with markdown support. The package enables character-by-character or word-by-word typing animations with RTL language support, fade-in effects, and real-time text streaming capabilities.

## Development Commands

### Flutter Package Development
```bash
flutter pub get              # Install dependencies
flutter pub deps             # Show dependency tree
flutter analyze             # Static analysis
flutter test                # Run unit tests
flutter test --coverage     # Run tests with coverage
dart format lib/ test/       # Format code
```

### Example App Development
```bash
cd example
flutter pub get              # Install example dependencies
flutter run                 # Run the example app
flutter run -d chrome       # Run on web
flutter build apk           # Build Android APK
flutter build ios           # Build iOS app
```

### Package Publishing
```bash
dart pub publish --dry-run   # Validate package before publishing
dart pub publish             # Publish to pub.dev
```

## Project Architecture

### Core Components

The package follows a layered architecture with clear separation of concerns:

**Main Widget Layer**:
- `StreamingTextMarkdown` - High-level widget combining scrolling, theming, and streaming text
- Handles auto-scrolling, theme resolution, and widget lifecycle management

**Core Text Engine**:
- `StreamingText` - Core text animation engine with comprehensive RTL support
- Manages character/word-by-word animations, fade-in effects, and Arabic text handling
- Contains sophisticated Arabic text processing with proper word boundary detection

**Theme System**:
- `StreamingTextTheme` - Professional theme extension system
- Supports both normal text styling and markdown style sheets
- Follows Flutter's theme inheritance pattern with fallback mechanisms

**Streaming Architecture**:
- `StreamProvider` interface for pluggable text sources
- `DefaultStreamProvider` for static text with typing animation
- Support for real-time `Stream<String>` integration

### RTL and Arabic Text Support

The package includes sophisticated Arabic and RTL text handling:

- **Arabic Detection**: Comprehensive Unicode range detection (U+0600-U+06FF, etc.)
- **Word Boundary Detection**: Custom Arabic word splitting logic
- **Animation Strategy**: Specialized grouping for Arabic character sequences
- **Direction Handling**: Automatic text direction detection and proper alignment

### Animation System

**Character-by-Character Mode**:
- Uses `Characters` package for proper Unicode handling
- Supports custom chunk sizes for batch character revelation
- RTL-aware animation sequencing

**Word-by-Word Mode**:
- Intelligent word boundary detection for multiple languages
- Arabic-specific word splitting with cultural considerations
- Configurable word chunk sizes

**Fade-in Animations**:
- Per-character animation controllers with memory management
- Customizable curves (easeOut, bounceOut, elasticOut, etc.)
- Automatic disable for Arabic text (performance optimization)

### Theme Integration

**Theme Hierarchy**:
1. Widget-level theme (explicit `theme` parameter)
2. Global theme extension (`StreamingTextTheme` in app theme)
3. Default theme based on Material Design context

**Style Resolution**:
- Automatic fallback to Material Design defaults
- Support for both light and dark themes
- Customizable padding, text styles, and markdown styling

## Key Features

### Markdown Support
- Headers (`#`, `##`, `###`)
- Bold (`**text**`) and italic (`*text*`)
- Lists (ordered and unordered)
- Custom `MarkdownStyleSheet` integration

### Real-time Streaming
- `Stream<String>` support for live text updates
- Error handling and completion callbacks
- Broadcasting capability for multiple listeners

### Performance Optimizations
- Animation controller pooling and cleanup
- RTL text grouping cache
- Conditional fade-in based on text content
- Memory-efficient character animation management

### Accessibility
- Semantic label support
- Proper text scaling with `TextScaler`
- Tap-to-complete functionality
- RTL navigation support

## Testing Strategy

### Unit Tests
- Widget rendering verification
- Animation property validation
- RTL text handling tests
- Stream integration tests
- Theme system tests

### Example App
The example app serves as both a demo and integration test with:
- Basic configuration demo with live settings
- LLM simulation demo showing real-time streaming
- Arabic and English text samples
- All animation modes and settings

## Code Conventions

### State Management
- Use `AnimationController` with proper disposal
- Timer-based typing animation with cancellation
- Stream subscription management with cleanup

### RTL Considerations
- Always check text direction before applying animations
- Use `Directionality` widgets for proper layout
- Arabic text should disable fade-in for performance

### Error Handling
- Graceful stream error display
- Animation cleanup on widget disposal
- Null-safe parameter handling throughout

## Development Notes

### Adding New Features
- Consider RTL implications for any text-related features
- Test with both Arabic and English content
- Ensure theme system compatibility
- Add corresponding example demonstrations

### Performance Considerations
- Arabic text animations use different strategies than LTR text
- Large texts should consider chunk-based processing
- Animation controllers require careful memory management
- Stream subscriptions must be properly cancelled

### Package Dependencies
- `flutter_markdown: ^0.7.6` - Core markdown rendering
- `characters: ^1.3.0` - Proper Unicode character handling
- `flutter_lints: ^3.0.1` - Linting for code quality