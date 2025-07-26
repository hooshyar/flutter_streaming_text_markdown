import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Streaming Text Markdown Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00BCD4),
          brightness: _isDarkMode ? Brightness.dark : Brightness.light,
        ).copyWith(
          primary: const Color(0xFF00BCD4),
          secondary: const Color(0xFF80DEEA),
          surface: _isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: _isDarkMode ? Colors.white : Colors.black,
          ),
        ),
      ),
      home: DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('LLM Streaming Demo'),
            actions: [
              IconButton(
                icon: Icon(
                  _isDarkMode ? Icons.light_mode : Icons.dark_mode,
                ),
                onPressed: _toggleTheme,
              ),
            ],
            bottom: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'ChatGPT Style'),
                Tab(text: 'Claude Style'),
                Tab(text: 'Controller Demo'),
                Tab(text: 'Custom Settings'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              ChatGPTDemoPage(isDarkMode: _isDarkMode),
              ClaudeDemoPage(isDarkMode: _isDarkMode),
              ControllerDemoPage(isDarkMode: _isDarkMode),
              MyHomePage(
                onThemeToggle: _toggleTheme,
                isDarkMode: _isDarkMode,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final Map<String, dynamic>? initialSettings;
  final VoidCallback onThemeToggle;
  final bool isDarkMode;

  const MyHomePage({
    super.key,
    this.initialSettings,
    required this.onThemeToggle,
    required this.isDarkMode,
  });

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _wordByWord = false;
  int _chunkSize = 1;
  bool _isArabic = false;
  Duration _typingSpeed = const Duration(milliseconds: 20);
  Duration _fadeInDuration = const Duration(milliseconds: 100);
  bool _fadeInEnabled = true;
  bool _markdownEnabled = false;
  Curve _fadeInCurve = Curves.easeOut;
  int _resetCounter = 0;

  final List<MapEntry<String, Curve>> _curves = [
    const MapEntry('Ease Out', Curves.easeOut),
    const MapEntry('Ease In', Curves.easeIn),
    const MapEntry('Elastic Out', Curves.elasticOut),
    const MapEntry('Bounce Out', Curves.bounceOut),
    const MapEntry('Decelerate', Curves.decelerate),
  ];

  final List<MapEntry<String, int>> _chunkSizes = [
    const MapEntry('1', 1),
    const MapEntry('2', 2),
    const MapEntry('3', 3),
    const MapEntry('5', 5),
    const MapEntry('10', 10),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialSettings != null) {
      _wordByWord = widget.initialSettings!['wordByWord'] ?? _wordByWord;
      _chunkSize = widget.initialSettings!['chunkSize'] ?? _chunkSize;
      _isArabic = widget.initialSettings!['isArabic'] ?? _isArabic;
      _typingSpeed = widget.initialSettings!['typingSpeed'] ?? _typingSpeed;
      _fadeInDuration =
          widget.initialSettings!['fadeInDuration'] ?? _fadeInDuration;
      _fadeInEnabled =
          widget.initialSettings!['fadeInEnabled'] ?? _fadeInEnabled;
      _markdownEnabled =
          widget.initialSettings!['markdownEnabled'] ?? _markdownEnabled;
      _fadeInCurve = widget.initialSettings!['fadeInCurve'] ?? _fadeInCurve;
    }
  }

  void _startStreaming() {
    setState(() {
      _resetCounter++;
    });
  }

  void _updateSettings({
    bool? wordByWord,
    int? chunkSize,
    bool? isArabic,
    Duration? typingSpeed,
    Duration? fadeInDuration,
    bool? fadeInEnabled,
    bool? markdownEnabled,
    Curve? fadeInCurve,
  }) {
    setState(() {
      if (wordByWord != null) _wordByWord = wordByWord;
      if (chunkSize != null) _chunkSize = chunkSize;
      if (isArabic != null) _isArabic = isArabic;
      if (typingSpeed != null) _typingSpeed = typingSpeed;
      if (fadeInDuration != null) _fadeInDuration = fadeInDuration;
      if (fadeInEnabled != null) _fadeInEnabled = fadeInEnabled;
      if (markdownEnabled != null) _markdownEnabled = markdownEnabled;
      if (fadeInCurve != null) _fadeInCurve = fadeInCurve;
      _resetCounter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArabic = _isArabic;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 380,
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: StreamingTextMarkdown(
                    key: ValueKey('streaming_text_$_resetCounter'),
                    text: isArabic
                        ? _markdownEnabled
                            ? '''# مرحباً بكم! 🤖

هذا **عرض توضيحي** للنص المتدفق.

يمكنك تجربة الأوضاع المختلفة:
1. حرف بحرف
2. كلمة بكلمة
3. مجموعات مخصصة

*هذا مثال بسيط* على قدراتنا في عرض النصوص العربية!'''
                            : '''مرحباً بكم! 🤖

هذا عرض توضيحي للنص المتدفق.

يمكنك تجربة الأوضاع المختلفة:
• حرف بحرف
• كلمة بكلمة
• مجموعات مخصصة

هذا مثال بسيط على قدراتنا في عرض النصوص العربية!'''
                        : _markdownEnabled
                            ? '''# Welcome to the Future! 🤖

This is an **AI-powered** text streaming demonstration.

Explore different modes:
1. Character by character
2. Word by word
3. Custom chunks

*Experience the future* of text animation!'''
                            : '''Welcome to the Future! 🤖

This is an AI-powered text streaming demonstration.

Explore different modes:
• Character by character
• Word by word
• Custom chunks

Experience the future of text animation!''',
                    initialText: isArabic
                        ? '# مرحباً بكم!\n\nجاري تهيئة النظام...\n\n'
                        : '# Welcome!\n\nInitializing system...\n\n',
                    fadeInEnabled: _fadeInEnabled,
                    fadeInDuration: _fadeInDuration,
                    fadeInCurve: _fadeInCurve,
                    wordByWord: _wordByWord,
                    chunkSize: _chunkSize,
                    typingSpeed: _typingSpeed,
                    textDirection:
                        isArabic ? TextDirection.rtl : TextDirection.ltr,
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    markdownEnabled: _markdownEnabled,
                  ),
                ),
                const SizedBox(height: 24),
                _buildSettingsCard(
                  title:
                      isArabic ? 'الإعدادات الأساسية' : 'System Configuration',
                  icon: Icons.settings_outlined,
                  children: [
                    _buildSwitch(
                      label: isArabic ? 'عربي' : 'Arabic',
                      value: _isArabic,
                      onChanged: (value) => _updateSettings(isArabic: value),
                    ),
                    _buildSwitch(
                      label: isArabic ? 'تنسيق ماركداون' : 'Markdown',
                      value: _markdownEnabled,
                      onChanged: (value) =>
                          _updateSettings(markdownEnabled: value),
                    ),
                    _buildSwitch(
                      label: isArabic ? 'كلمة بكلمة' : 'Word by Word',
                      value: _wordByWord,
                      onChanged: (value) => _updateSettings(wordByWord: value),
                    ),
                    if (!_wordByWord)
                      _buildDropdown<int>(
                        label: isArabic ? 'حجم المجموعة' : 'Chunk Size',
                        value: _chunkSize,
                        items: _chunkSizes,
                        onChanged: (value) {
                          if (value != null) {
                            _updateSettings(chunkSize: value);
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSettingsCard(
                  title: isArabic ? 'إعدادات الحركة' : 'Animation Parameters',
                  icon: Icons.animation_outlined,
                  children: [
                    _buildSwitch(
                      label: isArabic ? 'تأثير الظهور' : 'Fade-in Effect',
                      value: _fadeInEnabled,
                      onChanged: (value) =>
                          _updateSettings(fadeInEnabled: value),
                    ),
                    if (_fadeInEnabled) ...[
                      _buildSlider(
                        label:
                            isArabic ? 'مدة تأثير الظهور' : 'Fade-in Duration',
                        value: _fadeInDuration.inMilliseconds.toDouble(),
                        min: 100,
                        max: 2000,
                        divisions: 19,
                        onChanged: (value) => _updateSettings(
                          fadeInDuration: Duration(milliseconds: value.round()),
                        ),
                      ),
                      _buildDropdown<Curve>(
                        label: isArabic ? 'نوع الحركة' : 'Animation Curve',
                        value: _fadeInCurve,
                        items: _curves,
                        onChanged: (curve) {
                          if (curve != null) {
                            _updateSettings(fadeInCurve: curve);
                          }
                        },
                      ),
                    ],
                    _buildSlider(
                      label: isArabic ? 'سرعة الكتابة' : 'Typing Speed',
                      value: _typingSpeed.inMilliseconds.toDouble(),
                      min: 10,
                      max: 500,
                      divisions: 49,
                      onChanged: (value) => _updateSettings(
                        typingSpeed: Duration(milliseconds: value.round()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _startStreaming,
                  icon: const Icon(Icons.refresh_outlined),
                  label: Text(
                    isArabic ? 'إعادة التشغيل' : 'Reinitialize System',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required String title,
    required List<Widget> children,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitch({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: theme.colorScheme.primary,
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<MapEntry<String, T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
        DropdownButton<T>(
          value: value,
          items: items.map((item) {
            return DropdownMenuItem(
              value: item.value,
              child: Text(item.key),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              '${value.round()}ms',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: theme.colorScheme.primary,
            inactiveTrackColor: theme.colorScheme.primary.withValues(alpha: 0.2),
            thumbColor: theme.colorScheme.primary,
            overlayColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: '${value.round()}ms',
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// ChatGPT-style demo page
class ChatGPTDemoPage extends StatefulWidget {
  final bool isDarkMode;

  const ChatGPTDemoPage({super.key, required this.isDarkMode});

  @override
  State<ChatGPTDemoPage> createState() => _ChatGPTDemoPageState();
}

class _ChatGPTDemoPageState extends State<ChatGPTDemoPage> {
  final TextEditingController _promptController = TextEditingController();
  String _currentResponse = '';
  bool _isGenerating = false;
  Timer? _streamingTimer;
  int _currentIndex = 0;

  final List<String> _chatGPTResponses = [
    '''# Flutter Development Best Practices

**1. State Management**
- Use **Provider** for simple apps
- **Riverpod** for complex state
- **BLoC** for enterprise applications

**2. Performance Tips**
- Use `const` constructors
- Implement `ListView.builder` for long lists
- Avoid rebuilding widgets unnecessarily

**3. Code Organization**
```dart
lib/
  ├── models/
  ├── services/
  ├── widgets/
  └── screens/
```

*Remember: Clean code is maintainable code!*''',

    '''# Building Responsive Flutter Apps

**Key Principles:**
1. **LayoutBuilder** for adaptive layouts
2. **MediaQuery** for screen dimensions
3. **Flexible** and **Expanded** for space distribution

**Breakpoints:**
- Mobile: < 600px
- Tablet: 600px - 1200px  
- Desktop: > 1200px

**Code Example:**
```dart
LayoutBuilder(builder: (context, constraints) {
  if (constraints.maxWidth > 600) {
    return DesktopLayout();
  }
  return MobileLayout();
})
```

*Pro tip: Test on different screen sizes early!*''',

    '''# Flutter Animation Guide

**Animation Types:**
1. **Implicit Animations** - AnimatedContainer, AnimatedOpacity
2. **Explicit Animations** - AnimationController, Tween
3. **Hero Animations** - Seamless page transitions

**Performance Considerations:**
- Use `RepaintBoundary` for complex animations
- Prefer **Transform** over changing layout properties
- Cache heavy computations with `AnimationController`

**Example:**
```dart
AnimatedContainer(
  duration: Duration(milliseconds: 300),
  curve: Curves.easeInOut,
  width: _isExpanded ? 200 : 100,
  child: YourWidget(),
)
```

*Smooth animations enhance user experience!*''',
  ];

  final List<String> _samplePrompts = [
    "Explain Flutter state management best practices",
    "How to build responsive Flutter apps?",
    "Guide to Flutter animations and performance",
  ];

  void _startGenerating([String? customPrompt]) {
    final prompt = customPrompt ?? _promptController.text;
    if (prompt.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _currentResponse = '';
      if (customPrompt != null) {
        // Find matching response or use first one
        _currentIndex = _samplePrompts.indexWhere((p) => p.contains(prompt.split(' ')[0]));
        if (_currentIndex == -1) _currentIndex = 0;
      } else {
        _currentIndex = (_currentIndex + 1) % _chatGPTResponses.length;
      }
    });

    final response = _chatGPTResponses[_currentIndex];
    int charIndex = 0;

    _streamingTimer?.cancel();
    _streamingTimer = Timer.periodic(const Duration(milliseconds: 8), (timer) {
      if (charIndex < response.length) {
        setState(() {
          _currentResponse += response[charIndex];
        });
        charIndex++;
      } else {
        timer.cancel();
        setState(() {
          _isGenerating = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _streamingTimer?.cancel();
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Quick prompt buttons
          Wrap(
            spacing: 8,
            children: _samplePrompts.map((prompt) {
              return ElevatedButton(
                onPressed: _isGenerating ? null : () => _startGenerating(prompt),
                child: Text(prompt, style: const TextStyle(fontSize: 12)),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          
          // Input field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    decoration: const InputDecoration(
                      hintText: 'Ask about Flutter development...',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _startGenerating(),
                  ),
                ),
                IconButton(
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  onPressed: _isGenerating ? null : () => _startGenerating(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Response area
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: StreamingTextMarkdown.chatGPT(
                text: _currentResponse,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Claude-style demo page  
class ClaudeDemoPage extends StatefulWidget {
  final bool isDarkMode;

  const ClaudeDemoPage({super.key, required this.isDarkMode});

  @override
  State<ClaudeDemoPage> createState() => _ClaudeDemoPageState();
}

class _ClaudeDemoPageState extends State<ClaudeDemoPage> {
  final TextEditingController _promptController = TextEditingController();
  String _currentResponse = '';
  bool _isGenerating = false;
  Timer? _streamingTimer;
  int _currentIndex = 0;

  final List<String> _claudeResponses = [
    '''# Understanding Flutter Widget Trees

I'd be happy to explain Flutter's widget tree architecture and how it impacts performance.

## Widget Tree Fundamentals

Flutter's architecture is built around three key trees:

**1. Widget Tree**
- Describes the UI configuration
- Immutable and lightweight
- Rebuilds frequently during state changes

**2. Element Tree**  
- Manages the lifecycle of widgets
- Mutable and persistent
- Handles the actual widget mounting/unmounting

**3. Render Tree**
- Handles layout, painting, and hit testing
- Only rebuilds when necessary
- Most expensive operations happen here

## Performance Implications

The key insight is that Flutter tries to minimize work in the render tree by:
- Reusing elements when possible
- Only rebuilding widgets that actually changed
- Using keys to maintain state across rebuilds

## Best Practices

```dart
// Good: Use const constructors
const Text('Hello World')

// Good: Extract widgets to methods or classes
Widget buildHeader() => Container(...)

// Good: Use keys for dynamic lists
ListView(children: items.map((item) => 
  ItemWidget(key: ValueKey(item.id), item: item)
).toList())
```

This architecture enables Flutter's excellent performance while maintaining developer productivity.''',

    '''# Implementing Clean Architecture in Flutter

Let me walk you through implementing clean architecture in Flutter applications.

## Architecture Layers

Clean architecture organizes code into distinct layers with clear dependencies:

**1. Domain Layer (Core Business Logic)**
- Entities: Core business objects
- Use Cases: Application-specific business rules  
- Repository Interfaces: Abstract data contracts

**2. Data Layer**
- Repository Implementations
- Data Sources (Remote APIs, Local Databases)
- Models and DTOs

**3. Presentation Layer**
- UI Widgets
- State Management (BLoC, Provider, etc.)
- View Models/Controllers

## Dependency Direction

```
Presentation → Domain ← Data
```

Dependencies only flow inward. The domain layer knows nothing about Flutter or external frameworks.

## Implementation Example

```dart
// Domain Layer
abstract class UserRepository {
  Future<User> getUser(String id);
}

class GetUserUseCase {
  final UserRepository repository;
  GetUserUseCase(this.repository);
  
  Future<User> execute(String id) => repository.getUser(id);
}

// Data Layer  
class UserRepositoryImpl implements UserRepository {
  final UserDataSource dataSource;
  
  @override
  Future<User> getUser(String id) async {
    final dto = await dataSource.fetchUser(id);
    return dto.toDomain();
  }
}
```

## Benefits

- **Testability**: Easy to mock dependencies and test business logic
- **Maintainability**: Clear separation of concerns
- **Flexibility**: Easy to swap implementations
- **Scalability**: Architecture supports large teams and codebases

The investment in proper architecture pays dividends as your application grows.''',

    '''# Flutter State Management Comparison

I'll provide a comprehensive comparison of Flutter's most popular state management solutions.

## Provider (Recommended for Beginners)

**Pros:**
- Simple to learn and implement
- Built on InheritedWidget (Flutter's foundation)
- Great for small to medium apps
- Excellent debugging with Provider Inspector

**Cons:**
- Can become complex with multiple providers
- No built-in async state handling
- Performance can suffer with deeply nested widgets

**Example:**
```dart
ChangeNotifierProvider(
  create: (_) => CounterProvider(),
  child: Consumer<CounterProvider>(
    builder: (context, counter, _) => Text('\${counter.value}'),
  ),
)
```

## Riverpod (Provider's Evolution)

**Pros:**
- Compile-time safety
- No context dependency
- Excellent async support
- Built-in testing utilities

**Cons:**
- Steeper learning curve
- Relatively newer ecosystem

## BLoC (Business Logic Component)

**Pros:**
- Predictable state changes
- Excellent for large applications
- Platform agnostic
- Great testing support

**Cons:**
- Verbose boilerplate
- Steep learning curve
- Can be overkill for simple apps

## Recommendation Matrix

- **Small Apps (< 10 screens)**: Provider
- **Medium Apps (10-50 screens)**: Riverpod
- **Large Apps (50+ screens)**: BLoC or Riverpod
- **Enterprise**: BLoC with proper architecture

The key is choosing the right tool for your team's expertise and project requirements.''',
  ];

  final List<String> _claudePrompts = [
    "Explain Flutter widget trees and performance",
    "How to implement clean architecture in Flutter?",
    "Compare Flutter state management solutions",
  ];

  void _startGenerating([String? customPrompt]) {
    final prompt = customPrompt ?? _promptController.text;
    if (prompt.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _currentResponse = '';
      if (customPrompt != null) {
        _currentIndex = _claudePrompts.indexWhere((p) => p.contains(prompt.split(' ')[0]));
        if (_currentIndex == -1) _currentIndex = 0;
      } else {
        _currentIndex = (_currentIndex + 1) % _claudeResponses.length;
      }
    });

    final response = _claudeResponses[_currentIndex];
    int charIndex = 0;

    _streamingTimer?.cancel();
    _streamingTimer = Timer.periodic(const Duration(milliseconds: 12), (timer) {
      if (charIndex < response.length) {
        setState(() {
          _currentResponse += response[charIndex];
        });
        charIndex++;
      } else {
        timer.cancel();
        setState(() {
          _isGenerating = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _streamingTimer?.cancel();
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Quick prompt buttons
          Wrap(
            spacing: 8,
            children: _claudePrompts.map((prompt) {
              return ElevatedButton(
                onPressed: _isGenerating ? null : () => _startGenerating(prompt),
                child: Text(prompt, style: const TextStyle(fontSize: 12)),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          
          // Input field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    decoration: const InputDecoration(
                      hintText: 'Ask for detailed explanations...',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _startGenerating(),
                  ),
                ),
                IconButton(
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  onPressed: _isGenerating ? null : () => _startGenerating(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Response area
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: StreamingTextMarkdown.claude(
                text: _currentResponse,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Controller demo page
class ControllerDemoPage extends StatefulWidget {
  final bool isDarkMode;

  const ControllerDemoPage({super.key, required this.isDarkMode});

  @override
  State<ControllerDemoPage> createState() => _ControllerDemoPageState();
}

class _ControllerDemoPageState extends State<ControllerDemoPage> {
  final StreamingTextController _controller = StreamingTextController();
  String _currentText = '';
  String _stateText = 'Idle';
  double _progress = 0.0;

  final String _demoText = '''# StreamingTextController Demo

This demonstrates **programmatic control** over text streaming animations.

## Controller Features:
1. **Pause/Resume** - Stop and continue animations
2. **Skip to End** - Jump to complete text immediately  
3. **Restart** - Begin animation from the start
4. **Progress Tracking** - Monitor animation progress
5. **State Management** - Track current animation state

## Use Cases:
- User wants to **pause** during long responses
- **Skip** animation when re-reading content
- **Restart** to see the animation again
- Show **progress indicators** for long content

*Try the controls below to see the controller in action!*

This is perfect for **LLM applications** where users need control over the streaming experience.

## Technical Implementation:
```dart
final controller = StreamingTextController();

StreamingTextMarkdown.claude(
  text: llmResponse,
  controller: controller,
)

// Control the animation
controller.pause();
controller.resume();
controller.skipToEnd();
controller.restart();
```

The controller provides **real-time feedback** about animation state and progress, making it easy to build responsive UIs that adapt to user needs.''';

  @override
  void initState() {
    super.initState();
    _controller.onStateChanged((state) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _stateText = state.description;
            });
          }
        });
      }
    });
    
    _controller.onProgressChanged((progress) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _progress = progress;
            });
          }
        });
      }
    });
    
    // Start with the demo text after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDemo();
    });
  }

  void _startDemo() {
    setState(() {
      _currentText = _demoText;
    });
    _controller.restart();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _controller.isAnimating ? _controller.pause : _controller.resume,
                icon: Icon(_controller.isAnimating ? Icons.pause : Icons.play_arrow),
                label: Text(_controller.isAnimating ? 'Pause' : 'Resume'),
              ),
              ElevatedButton.icon(
                onPressed: _controller.skipToEnd,
                icon: const Icon(Icons.skip_next),
                label: const Text('Skip'),
              ),
              ElevatedButton.icon(
                onPressed: _startDemo,
                icon: const Icon(Icons.refresh),
                label: const Text('Restart'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Status info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('State: $_stateText', style: Theme.of(context).textTheme.titleMedium),
                      Text('Progress: ${(_progress * 100).toInt()}%', 
                           style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _progress),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Text display
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: StreamingTextMarkdown.claude(
                text: _currentText,
                controller: _controller,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
