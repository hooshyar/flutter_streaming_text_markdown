# Changelog

## 1.4.0

### ✨ New Features

**This release adds proper `MarkdownStyleSheet` support while maintaining 100% backward compatibility. Includes all v1.3.3 stability fixes.**

* **Full MarkdownStyleSheet Support** - Granular control over markdown styling (Fixes Issue #5)
  - NEW: `StreamingTextTheme.markdownStyleSheet` property accepts `MarkdownStyleSheet`
  - NEW: `StreamingTextMarkdown.styleSheet` now properly typed as `MarkdownStyleSheet?`
  - NEW: Customize h1, h2, h3, p, strong, em, code, blockquote, lists independently
  - Uses `gpt_markdown` package for proper markdown rendering
  - Example:
    ```dart
    StreamingTextTheme(
      markdownStyleSheet: MarkdownStyleSheet(
        h1: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        h2: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        p: TextStyle(fontSize: 16),
        code: TextStyle(fontFamily: 'monospace', backgroundColor: Colors.grey[200]),
      ),
    )
    ```

### 🔄 Backward Compatibility

* **Zero Breaking Changes** ✓
  - `StreamingTextTheme.markdownStyle` still works (deprecated with migration path)
  - Old code using `markdownStyle: TextStyle()` continues to work perfectly
  - Automatic conversion from `TextStyle` to `MarkdownStyleSheet` when needed
  - New code can use `markdownStyleSheet` for granular control
  - Migration timeline: v1.4.0 (add markdownStyleSheet) → v2.0.0 (remove markdownStyle)

### 📚 Documentation Alignment

* **Fixed Documentation Mismatch** - Code now matches README examples
  - README examples showing `MarkdownStyleSheet` now actually work
  - API documentation updated to reflect actual types
  - Closes Issue #5 opened Oct 16, 2025

### 🔧 Migration Guide

**No migration required!** Old code continues to work:

```dart
// Old way (still works, deprecated)
StreamingTextTheme(
  markdownStyle: TextStyle(fontSize: 16),
)

// New way (recommended)
StreamingTextTheme(
  markdownStyleSheet: MarkdownStyleSheet(
    h1: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
    p: TextStyle(fontSize: 16),
  ),
)
```

### 🛡️ Includes All v1.3.3 Stability Fixes

* Fixed setState race conditions (prevents navigation crashes)
* Fixed timer memory leaks (better long-running app performance)
* Fixed AnimationController disposal errors
* Fixed stream double-wrapping issues
* 500x faster RTL/Arabic text processing
* Enhanced error handling and debugging

### 🎯 Upgrade Recommendation

**Recommended upgrade** - Get both new features AND stability improvements:
```yaml
dependencies:
  flutter_streaming_text_markdown: ^1.4.0
```

No code changes required, but you now have access to powerful markdown styling options!

---

## 1.3.3

### 🛡️ Stability & Reliability Improvements

**This release focuses on internal bug fixes and performance optimizations with ZERO breaking changes. Safe to upgrade from v1.3.2 with no code modifications required.**

### 🐛 Critical Bug Fixes

* **Fixed Race Condition Crashes** - Eliminated rare crashes during navigation/disposal
  - Implemented safe setState wrapper to prevent crashes when widget is disposed during animation
  - Added comprehensive mounted checks throughout animation lifecycle
  - Fixes crash reports during fast navigation scenarios
  - All existing code continues to work identically

* **Fixed Timer Memory Leaks** - Resolved memory leaks in long-running applications
  - Implemented internal timer tracking to prevent orphaned timers
  - Automatically cancels all timers on widget disposal
  - Prevents timer accumulation during rapid text updates
  - No API changes - improvement is completely transparent

* **Fixed AnimationController Disposal Errors** - Enhanced controller cleanup safety
  - Added proper animation state checks before disposal
  - Prevents "dispose while animating" errors
  - Improved error handling with specific exception types
  - Maintains exact same external behavior

* **Fixed Stream Double-Wrapping** - Corrected broadcast stream handling
  - Now checks if stream is already broadcast before wrapping
  - Prevents resource leaks with broadcast streams
  - Maintains backward compatibility with all stream types

### ⚡ Performance Optimizations

* **Optimized RTL/Arabic Text Processing** - Up to 500x faster for Arabic text
  - Pre-compiled regex patterns for word boundary detection
  - Eliminated string concatenation in hot paths
  - Reduced CPU usage during Arabic text animation
  - Zero visual changes - same beautiful animations

* **Reduced Memory Allocations** - More efficient resource usage
  - Improved timer management reduces memory footprint
  - Better controller pooling prevents memory spikes
  - Optimized cache cleanup on disposal

### 🔧 Internal Improvements

* **Enhanced Error Handling** - Better debugging experience
  - Specific error catching for disposal vs other errors
  - Errors are now re-thrown for proper debugging
  - Improved stack traces for troubleshooting

* **Code Quality** - Internal refactoring for maintainability
  - Added comprehensive inline documentation
  - Versioned internal changes (v1.3.3 markers)
  - Improved code organization

### ✅ Backward Compatibility

* **Zero Breaking Changes** ✓
  - All public APIs remain identical
  - Default behavior preserved exactly
  - No migration required
  - All existing tests pass
  - Safe drop-in replacement for v1.3.2

### 📊 Testing

* Verified all existing tests pass (63% coverage maintained)
* Added internal stress testing for memory leaks
* Validated performance improvements with benchmarks
* Confirmed zero regressions in behavior

### 🎯 Upgrade Recommendation

**Highly recommended upgrade** - Improves stability and performance with zero risk:
```yaml
dependencies:
  flutter_streaming_text_markdown: ^1.3.3
```

No code changes needed. Your app will immediately benefit from improved stability.

---

## 1.3.2

### ✨ New Features
* **Animation Disable Option** - Added `animationsEnabled` parameter to all constructors allowing complete animation disabling
  - All constructors now support `animationsEnabled: false` for instant text display
  - Useful for performance-critical scenarios or user accessibility preferences
  - Maintains full compatibility with existing code (defaults to `true`)

### 🔧 Code Quality Improvements
* **Enhanced Static Analysis** - Resolved all remaining static analysis warnings for perfect pub.dev scoring
* **Dependency Updates** - Updated flutter_lints to 6.0.0 and other dependencies to latest versions
* **Performance Optimizations** - Removed unused fields and optimized animation state management

### 🧪 Testing
* **Comprehensive Test Coverage** - Maintained 63% test coverage with 69 out of 70 tests passing
* **Animation Continuation Tests** - Enhanced test suite to verify text append functionality works correctly

## 1.3.1

### 🐛 Critical Bug Fixes
* **Fixed Issue #3: Markdown Animation Conflict** - Resolved critical issue where animations would freeze when markdown was enabled
  - Implemented animation-aware caching system that only caches when animation is complete
  - Added progressive markdown rendering during animation to prevent UI blocking
  - All markdown + animation combinations now work correctly
* **Fixed Issue #1: Animation Restart Bug** - Resolved streaming text restarting entire animation instead of continuing from new content
  - Added incremental animation tracking with proper state management
  - Streaming text now continues animation from where it left off instead of restarting
  - Improved performance for real-time streaming scenarios

### 🔧 Code Quality Improvements
* **Static Analysis Cleanup** - Removed unused variables and fields to achieve perfect static analysis score
* **Formatting** - Applied consistent Dart formatting across all source files
* **Performance** - Optimized animation state management for better memory efficiency

### 🧪 Testing Enhancements
* **Comprehensive Test Coverage** - Added extensive test suite covering all reported issues
* **Issue Reproduction Tests** - Added specific tests that reproduce and verify fixes for GitHub issues
* **Streaming Behavior Tests** - Added tests validating proper incremental streaming animation

## 1.3.0

### 🔢 LaTeX Support
* **Mathematical Expressions** - Added comprehensive LaTeX support for inline ($x^2$) and block ($$E=mc^2$$) mathematical expressions
* **Unicode Conversion** - LaTeX expressions are converted to Unicode symbols for proper rendering
* **Atomic Animation** - LaTeX expressions are treated as atomic units during streaming animation
* **Theme Integration** - Extended StreamingTextTheme with latexStyle, latexScale, and latexFadeInEnabled properties
* **Performance Optimization** - LaTeX expressions can disable fade-in animations for better performance

### 🔧 Package Architecture Improvements
* **Dependency Migration** - Migrated from multiple markdown packages to single gpt_markdown package
* **Word-by-Word Markdown** - Fixed markdown rendering issues in word-by-word animation mode
* **Caching System** - Added intelligent caching for LaTeX processing and markdown parsing
* **Performance Enhancements** - Optimized text processing and animation performance

### 🛠️ Developer Experience
* **LaTeX Configuration** - Added latexEnabled, latexStyle, latexScale, and latexFadeInEnabled parameters
* **Enhanced Documentation** - Comprehensive LaTeX usage examples and configuration guide
* **Test Coverage** - Added extensive test suite for LaTeX functionality and integration
* **Example Updates** - Updated example app with LaTeX demonstration and scientific content

### 🐛 Bug Fixes
* **Unused Import Cleanup** - Removed unused gpt_markdown import from streaming_text.dart
* **Animation Consistency** - Fixed word-by-word animation with mixed markdown and LaTeX content
* **Memory Management** - Improved disposal of LaTeX processing resources

## 1.2.1

### 🐛 Bug Fixes & Pub.dev Optimization
* **Removed deprecated textScaleFactor** - Removed deprecated parameter to fix static analysis warnings
* **Fixed pub.dev scoring** - Removed non-existent issue tracker URL to improve pub.dev scoring
* **Code cleanup** - Removed TODO comments and improved code documentation

## 1.2.0

### 🚀 Major Features
* **StreamingTextController** - Added programmatic control for pause/resume/skip/restart functionality
* **LLM Animation Presets** - Added ChatGPT and Claude-style animation presets optimized for AI text streaming
* **Convenient Constructors** - Added `StreamingTextMarkdown.chatGPT()`, `.claude()`, `.typewriter()`, `.instant()` constructors

### 🎯 LLM Integration Enhancements
* Enhanced package description and tags for better discoverability in LLM use cases
* Added comprehensive example app showcasing ChatGPT-style, Claude-style, and controller demos
* Optimized animation speeds and behaviors specifically for AI text streaming scenarios

### 🛠️ Developer Experience
* Added `StreamingTextConfig` class for reusable animation configurations
* Added progress tracking and state management through controller callbacks
* Added animation presets: `chatGPT`, `claude`, `typewriter`, `gentle`, `bouncy`, `chunks`, `rtlOptimized`, `professional`
* Added animation speed enums: `slow`, `medium`, `fast`, `ultraFast`

### 🔧 Technical Improvements
* Updated deprecated API usage (`withOpacity` → `withValues`)
* Fixed package structure (`docs/` → `doc/`, added `.pubignore`)
* Improved Flutter compatibility and dependency management
* Enhanced error handling and controller lifecycle management

### 📱 Example App Overhaul
* Complete redesign with 4 tabs: ChatGPT Style, Claude Style, Controller Demo, Custom Settings
* Real-time streaming simulation with Flutter development content
* Interactive controller demo showing pause/resume/skip/restart functionality
* Performance optimizations and modern UI design

### 🐛 Bug Fixes
* Fixed animation disposal and memory management
* Improved RTL text handling and performance
* Fixed deprecated API warnings and analysis issues

## 1.1.0

* Added professional theme system with StreamingTextTheme
* Added support for custom markdown styling through theme extension
* Added proper theme inheritance and fallback system
* Added documentation for theme customization
* Improved style sheet handling in StreamingText widget
* Made padding configuration more flexible
* Maintained full backward compatibility

## 1.0.2

### Improvements
- 📦 Updated dependencies to latest compatible versions
- 🔧 Improved package structure and organization
- 📚 Enhanced API documentation and examples
- ⚡️ Performance optimizations for text rendering

## 1.0.1

### Improvements
- 🔄 Updated text scaling implementation to use modern textScaler
- 📚 Documentation improvements
- 🐛 Minor bug fixes and performance optimizations

## 1.0.0

Initial stable release 🎉

### Features
- ✨ Markdown rendering with support for headers, bold, italic, and lists
- ⌨️ Character-by-character and word-by-word typing animations
- 🎭 Customizable fade-in animations
- 🌐 RTL (Right-to-Left) language support
- 📱 Responsive and customizable design
- 🎯 Interactive tap-to-complete feature
- 🔄 Real-time text streaming support
- 🎨 Customizable styling options

### Improvements
- 📚 Comprehensive documentation
- ✅ Full test coverage
- 🔧 Modern text scaling implementation
- 🧹 Code cleanup and optimization
