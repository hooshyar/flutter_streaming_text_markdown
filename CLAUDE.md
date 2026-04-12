# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Flutter package (`flutter_streaming_text_markdown`) for animated text display with markdown and LaTeX support. Designed for LLM chat interfaces — provides typing animations (character-by-character or word-by-word), fade-in effects, RTL/Arabic support, and real-time text streaming. Published on pub.dev.

## Development Commands

```bash
flutter pub get              # Install dependencies
flutter analyze              # Static analysis
flutter test                 # Run all tests
flutter test test/latex_processor_test.dart  # Run a single test file
dart format lib/ test/       # Format code
dart pub publish --dry-run   # Validate before publishing
```

Example app (do NOT run unless explicitly asked):
```bash
cd example && flutter pub get && flutter run
```

## Architecture

### Widget Hierarchy

`StreamingTextMarkdown` (public API, in `lib/flutter_streaming_text_markdown.dart`)
  → wraps `StreamingText` (internal engine, `lib/src/streaming/streaming_text.dart`)

`StreamingTextMarkdown` handles scrolling, theme resolution, and shimmer loading state. `StreamingText` handles all animation logic, text chunking, Arabic detection, and markdown rendering via `gpt_markdown` (NOT `flutter_markdown`).

### Named Constructors as Presets

The main widget has named constructors for common LLM patterns: `.chatGPT()`, `.claude()`, `.typewriter()`, `.instant()`, `.fromPreset()`. These set animation defaults (typing speed, word-by-word, fade-in, chunk size). The `LLMAnimationPresets` class in `lib/src/presets/animation_presets.dart` provides the same configs as `StreamingTextConfig` objects.

### Theme System

`StreamingTextTheme` extends `ThemeExtension<StreamingTextTheme>` — it plugs into Flutter's standard theme system. Resolution order:
1. Widget-level `theme` parameter
2. `Theme.of(context).extension<StreamingTextTheme>()`
3. `StreamingTextTheme.defaults(context)` — derives from Material theme

The `context.streamingTextTheme` extension provides convenient access.

Note: `markdownStyle` is deprecated in favor of `markdownStyleSheet` — removal planned for v2.0.0.

### LaTeX Support

`LaTeXProcessor` (`lib/src/utils/latex_processor.dart`) parses text into `TextSegment`s (regular, inlineLaTeX, blockLaTeX). Block expressions (`$$...$$`) take priority over inline (`$...$`). LaTeX fade-in is disabled by default for performance.

### RTL / Arabic Text

Arabic detection uses Unicode ranges (U+0600-U+06FF etc.) in `StreamingText`. Key behaviors:
- Fade-in is automatically disabled for Arabic text (performance)
- Word-by-word mode uses custom Arabic word boundary detection
- `Directionality` widget wraps output for proper layout

### Controller

`StreamingTextController` extends `ChangeNotifier` — provides pause/resume/restart/skipToEnd/stop and progress tracking (0.0–1.0). States: idle → animating → paused/completed/error.

### Shimmer Loading

`StreamingShimmer` widget (`lib/src/widgets/streaming_shimmer.dart`) shows skeleton placeholder while `isLoading: true`. Used for TTFT (Time To First Token) in LLM contexts.

### Exports

`lib/flutter_streaming_text_markdown.dart` is the barrel file. It exports: `streaming.dart` (StreamProvider, DefaultStreamProvider, StreamingText), `streaming_text_theme.dart`, `streaming_text_controller.dart`, `animation_presets.dart`. The `StreamingText` widget is imported but not re-exported (internal).
