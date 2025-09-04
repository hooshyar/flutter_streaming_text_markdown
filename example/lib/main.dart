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
        length: 6,
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
                Tab(text: 'LaTeX Demo'),
                Tab(text: 'Controller Demo'),
                Tab(text: 'New Features'),
                Tab(text: 'Custom Settings'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              ChatGPTDemoPage(isDarkMode: _isDarkMode),
              ClaudeDemoPage(isDarkMode: _isDarkMode),
              LaTeXDemoPage(isDarkMode: _isDarkMode),
              ControllerDemoPage(isDarkMode: _isDarkMode),
              NewFeaturesDemoPage(isDarkMode: _isDarkMode),
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
  String _demoText = 'Initial demo text';

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
      // Just trigger rebuild to restart animation
    });
  }

  void _appendDemoText() {
    setState(() {
      _demoText += '\n\nAppended text: ${DateTime.now().second}s';
    });
  }

  void _resetDemoText() {
    setState(() {
      _demoText = 'Initial demo text';
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
                    key: const ValueKey('streaming_text_demo'),
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
                const SizedBox(height: 16),
                _buildSettingsCard(
                  title: isArabic ? 'الميزات الجديدة - تجربة' : 'New Features Demo',
                  icon: Icons.new_releases_outlined,
                  children: [
                    Text(
                      isArabic 
                        ? '🚀 استمرار الحركة عند إضافة النص\n🎛️ إيقاف الحركات تماماً'
                        : '🚀 Animation continues when text is appended\n🎛️ Complete animation disable option',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _appendDemoText,
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(
                              isArabic ? 'إضافة نص' : 'Append Text',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _resetDemoText,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: Text(
                              isArabic ? 'إعادة تعيين' : 'Reset',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isArabic ? 'نص التجربة:' : 'Demo Text:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _demoText,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
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
          activeThumbColor: theme.colorScheme.primary,
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
            inactiveTrackColor:
                theme.colorScheme.primary.withValues(alpha: 0.2),
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
    '''# Flutter Best Practices

**State Management:**
- **Provider** for simple apps
- **Riverpod** for complex state
- **BLoC** for enterprise

**Performance:**
- Use `const` constructors
- `ListView.builder` for long lists

*Clean code is maintainable code!*''',
    '''# Responsive Flutter

**Key Tools:**
- **LayoutBuilder** for adaptive layouts
- **MediaQuery** for screen dimensions

**Breakpoints:**
- Mobile: < 600px
- Desktop: > 600px

*Test on different screen sizes early!*''',
    '''# Flutter Animations

**Types:**
- **Implicit** - AnimatedContainer
- **Explicit** - AnimationController  
- **Hero** - Page transitions

**Performance:**
- Use `RepaintBoundary`
- Prefer **Transform**

*Smooth animations enhance UX!*''',
  ];

  final List<String> _samplePrompts = [
    "Best practices",
    "Responsive design",
    "Animations guide",
  ];

  void _startGenerating([String? customPrompt]) {
    final prompt = customPrompt ?? _promptController.text;
    if (prompt.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _currentResponse = '';
      if (customPrompt != null) {
        // Find matching response or use first one
        _currentIndex =
            _samplePrompts.indexWhere((p) => p.contains(prompt.split(' ')[0]));
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
                onPressed:
                    _isGenerating ? null : () => _startGenerating(prompt),
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
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.2),
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
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.2),
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
    '''# Flutter Widget Trees

Flutter's architecture uses three key trees:

**1. Widget Tree** - UI configuration
**2. Element Tree** - Lifecycle management  
**3. Render Tree** - Layout and painting

## Performance Tips

- Use `const` constructors
- Extract widgets to methods
- Use keys for dynamic lists

This architecture enables excellent performance.''',
    '''# Clean Architecture

Organize code into layers:

**Domain Layer** - Business logic
**Data Layer** - Repository implementations
**Presentation Layer** - UI widgets

## Dependency Direction
```
Presentation → Domain ← Data
```

Benefits: testability, maintainability, flexibility.''',
    '''# State Management

**Provider** - Simple, great for beginners
**Riverpod** - Compile-time safety, async support  
**BLoC** - Predictable, excellent for large apps

## Recommendations
- Small apps: Provider
- Medium apps: Riverpod
- Large apps: BLoC

Choose based on team expertise and project size.''',
  ];

  final List<String> _claudePrompts = [
    "Widget trees",
    "Clean architecture",
    "State management",
  ];

  void _startGenerating([String? customPrompt]) {
    final prompt = customPrompt ?? _promptController.text;
    if (prompt.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _currentResponse = '';
      if (customPrompt != null) {
        _currentIndex =
            _claudePrompts.indexWhere((p) => p.contains(prompt.split(' ')[0]));
        if (_currentIndex == -1) _currentIndex = 0;
      } else {
        _currentIndex = (_currentIndex + 1) % _claudeResponses.length;
      }
    });

    final response = _claudeResponses[_currentIndex];
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
            children: _claudePrompts.map((prompt) {
              return ElevatedButton(
                onPressed:
                    _isGenerating ? null : () => _startGenerating(prompt),
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
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.2),
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
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.2),
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
  final String _currentText = '''# Controller Demo

Programmatic control over text streaming:

## Features:
- **Pause/Resume** animations
- **Skip to End** instantly  
- **Restart** from beginning
- **Progress Tracking**

## Use Cases:
- Pause during long responses
- Skip when re-reading
- Show progress indicators

*Try the controls below!*

Perfect for **LLM applications**.

```dart
final controller = StreamingTextController();
controller.pause();
controller.resume();
controller.skipToEnd();
```''';
  String _stateText = 'Idle';
  double _progress = 0.0;

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
    // _currentText is already initialized, just restart the controller
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
                onPressed: _controller.isAnimating
                    ? _controller.pause
                    : _controller.resume,
                icon: Icon(
                    _controller.isAnimating ? Icons.pause : Icons.play_arrow),
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
                      Text('State: $_stateText',
                          style: Theme.of(context).textTheme.titleMedium),
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
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.2),
                ),
              ),
              child: StreamingTextMarkdown.claude(
                text: _currentText,
                controller: _controller,
                markdownEnabled: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// LaTeX demo page
class LaTeXDemoPage extends StatefulWidget {
  final bool isDarkMode;

  const LaTeXDemoPage({super.key, required this.isDarkMode});

  @override
  State<LaTeXDemoPage> createState() => _LaTeXDemoPageState();
}

class _LaTeXDemoPageState extends State<LaTeXDemoPage> {
  final TextEditingController _promptController = TextEditingController();
  String _currentResponse = '';
  bool _isGenerating = false;
  Timer? _streamingTimer;
  int _currentIndex = 0;
  bool _latexEnabled = true;
  bool _markdownEnabled = true;

  final List<String> _latexExamples = [
    '''# Basic Math

Inline: \$x = 5\$ and \$y = 10\$

Operations: \$a + b\$, \$x^2\$, \$\\frac{a}{b}\$

Block equation:
\$\$E = mc^2\$\$''',
    '''# Quadratic Formula

Solve \$ax^2 + bx + c = 0\$:

\$\$x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}\$\$

Derivative: \$\\frac{d}{dx}[x^n] = nx^{n-1}\$''',
    '''# Physics

Newton's law: \$F = ma\$

Energy: \$KE = \\frac{1}{2}mv^2\$

Wave equation:
\$\$\\frac{\\partial^2 y}{\\partial t^2} = v^2\\frac{\\partial^2 y}{\\partial x^2}\$\$''',
    '''# Computer Science

Big O: \$O(1)\$, \$O(n)\$, \$O(n^2)\$

Machine Learning:
\$\$y = \\beta_0 + \\beta_1 x + \\epsilon\$\$

Sigmoid: \$\\sigma(z) = \\frac{1}{1 + e^{-z}}\$''',
  ];

  final List<String> _samplePrompts = [
    "Basic math",
    "Quadratic formula",
    "Physics formulas",
    "Computer science",
  ];

  void _startGenerating([String? customPrompt]) {
    final prompt = customPrompt ?? _promptController.text;
    if (prompt.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _currentResponse = '';
      if (customPrompt != null) {
        _currentIndex = _samplePrompts.indexWhere((p) =>
            p.toLowerCase().contains(prompt.toLowerCase().split(' ')[0]));
        if (_currentIndex == -1) _currentIndex = 0;
      } else {
        _currentIndex = (_currentIndex + 1) % _latexExamples.length;
      }
    });

    final response = _latexExamples[_currentIndex];
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
          // LaTeX controls
          Row(
            children: [
              Switch(
                value: _latexEnabled,
                onChanged: (value) => setState(() => _latexEnabled = value),
              ),
              const SizedBox(width: 8),
              const Text('LaTeX Rendering'),
              const SizedBox(width: 24),
              Switch(
                value: _markdownEnabled,
                onChanged: (value) => setState(() => _markdownEnabled = value),
              ),
              const SizedBox(width: 8),
              const Text('Markdown'),
            ],
          ),
          const SizedBox(height: 16),

          // Quick prompt buttons
          Wrap(
            spacing: 8,
            children: _samplePrompts.map((prompt) {
              return ElevatedButton(
                onPressed:
                    _isGenerating ? null : () => _startGenerating(prompt),
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
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    decoration: const InputDecoration(
                      hintText: 'Ask for mathematical formulas...',
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
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.2),
                ),
              ),
              child: StreamingTextMarkdown(
                text: _currentResponse,
                latexEnabled: _latexEnabled,
                markdownEnabled: _markdownEnabled,
                typingSpeed: const Duration(milliseconds: 20),
                wordByWord: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// New Features demo page
class NewFeaturesDemoPage extends StatefulWidget {
  final bool isDarkMode;

  const NewFeaturesDemoPage({super.key, required this.isDarkMode});

  @override
  State<NewFeaturesDemoPage> createState() => _NewFeaturesDemoPageState();
}

class _NewFeaturesDemoPageState extends State<NewFeaturesDemoPage> {
  String _demoText = 'Initial text for animation continuation demo.';
  bool _animationsEnabled = true;
  int _updateCounter = 0;

  void _appendText() {
    setState(() {
      _updateCounter++;
      _demoText += '\n\nAppended text #$_updateCounter at ${DateTime.now().second}s';
    });
  }

  void _resetText() {
    setState(() {
      _updateCounter = 0;
      _demoText = 'Initial text for animation continuation demo.';
    });
  }

  void _toggleAnimations() {
    setState(() {
      _animationsEnabled = !_animationsEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Feature description
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🚀 New Features Demo',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Feature #1: Animation Continuation',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '✓ When text is appended, animation continues smoothly instead of restarting',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Feature #2: Animation Disable Option',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '✓ Complete control to disable animations when needed',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Controls
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _appendText,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Append Text'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _resetText,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reset'),
              ),
              const Spacer(),
              Switch(
                value: _animationsEnabled,
                onChanged: (_) => _toggleAnimations(),
              ),
              const SizedBox(width: 8),
              Text('Animations ${_animationsEnabled ? 'ON' : 'OFF'}'),
            ],
          ),
          const SizedBox(height: 16),

          // Demo area
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: StreamingTextMarkdown(
                key: const ValueKey('new_features_demo'),
                text: _demoText,
                markdownEnabled: true,
                wordByWord: true,
                typingSpeed: const Duration(milliseconds: 50),
                animationsEnabled: _animationsEnabled,
                onComplete: () {
                  // Animation completed - schedule snackbar for after build
                  if (mounted) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Animation completed!'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      }
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

