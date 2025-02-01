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
        cardTheme: CardTheme(
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
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Streaming Text Demo'),
            actions: [
              IconButton(
                icon: Icon(
                  _isDarkMode ? Icons.light_mode : Icons.dark_mode,
                ),
                onPressed: _toggleTheme,
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Basic Demo'),
                Tab(text: 'LLM Demo'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              MyHomePage(
                onThemeToggle: _toggleTheme,
                isDarkMode: _isDarkMode,
              ),
              LLMDemoPage(isDarkMode: _isDarkMode),
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
                      color: theme.colorScheme.primary.withAlpha(100),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withAlpha(100),
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
          color: theme.colorScheme.primary.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.1),
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
            inactiveTrackColor: theme.colorScheme.primary.withOpacity(0.2),
            thumbColor: theme.colorScheme.primary,
            overlayColor: theme.colorScheme.primary.withOpacity(0.1),
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

class LLMDemoPage extends StatefulWidget {
  final bool isDarkMode;

  const LLMDemoPage({
    super.key,
    required this.isDarkMode,
  });

  @override
  State<LLMDemoPage> createState() => _LLMDemoPageState();
}

class _LLMDemoPageState extends State<LLMDemoPage> {
  final TextEditingController _promptController = TextEditingController();
  String _currentResponse = '';
  bool _isGenerating = false;
  Timer? _streamingTimer;
  int _currentIndex = 0;

  final List<String> _sampleResponses = [
    '''Here's a detailed explanation of how async/await works in Dart:

1. **Basics of Async Programming**:
   - Async programming helps handle operations that might take time
   - It prevents blocking the main thread
   - Uses Future objects to represent potential values

2. **The async Keyword**:
   - Marks a function as asynchronous
   - Always returns a Future
   - Enables the use of await

3. **The await Keyword**:
   - Pauses execution until a Future completes
   - Can only be used in async functions
   - Makes async code look synchronous

4. **Error Handling**:
   - Use try/catch blocks
   - Handle errors gracefully
   - Maintain app stability

Remember: Good async programming is crucial for responsive apps!''',
    '''Let me explain the key principles of Material Design 3:

1. **Dynamic Color**:
   - Uses color extraction from wallpapers
   - Creates personalized color schemes
   - Maintains accessibility

2. **Typography**:
   - Updated type scale
   - Better readability
   - Responsive sizing

3. **Component Updates**:
   - New navigation bar
   - Enhanced FAB designs
   - Improved cards

4. **Elevation and Shadows**:
   - Refined surface hierarchy
   - Better depth perception
   - Consistent elevation system

These principles create modern, beautiful apps!''',
    '''Here's how to implement clean architecture in Flutter:

1. **Layers**:
   - Domain (Business Logic)
   - Data (Repository Pattern)
   - Presentation (UI/UX)

2. **Dependencies**:
   - Dependency Injection
   - Interface Segregation
   - Clean Dependencies

3. **Testing**:
   - Unit Tests
   - Integration Tests
   - Widget Tests

4. **Benefits**:
   - Maintainable Code
   - Scalable Architecture
   - Easy Testing

Follow these principles for robust apps!''',
  ];

  void _startGenerating() {
    if (_promptController.text.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _currentResponse = '';
      _currentIndex = (_currentIndex + 1) % _sampleResponses.length;
    });

    final response = _sampleResponses[_currentIndex];
    int charIndex = 0;

    _streamingTimer?.cancel();
    _streamingTimer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    decoration: const InputDecoration(
                      hintText: 'Enter your prompt...',
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
                  onPressed: _isGenerating ? null : _startGenerating,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                ),
              ),
              child: StreamingTextMarkdown(
                text: _currentResponse,
                typingSpeed: const Duration(milliseconds: 50),
                fadeInEnabled: true,
                fadeInDuration: const Duration(milliseconds: 200),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
