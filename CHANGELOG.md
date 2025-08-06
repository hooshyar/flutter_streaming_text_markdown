# Changelog

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
