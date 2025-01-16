import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

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
          background:
              _isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
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
      home: MyHomePage(
        onThemeToggle: _toggleTheme,
        isDarkMode: _isDarkMode,
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
  int _resetCounter = 0;

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
  }) {
    setState(() {
      if (wordByWord != null) _wordByWord = wordByWord;
      if (chunkSize != null) _chunkSize = chunkSize;
      if (isArabic != null) _isArabic = isArabic;
      if (typingSpeed != null) _typingSpeed = typingSpeed;
      if (fadeInDuration != null) _fadeInDuration = fadeInDuration;
      if (fadeInEnabled != null) _fadeInEnabled = fadeInEnabled;
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
        backgroundColor: theme.colorScheme.background,
        appBar: AppBar(
          title: Text(isArabic ? 'عرض النص المتدفق' : 'AI Text Streaming'),
          actions: [
            IconButton(
              icon: Icon(
                widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                color: theme.colorScheme.primary,
              ),
              onPressed: widget.onThemeToggle,
              tooltip: widget.isDarkMode
                  ? 'Switch to light mode'
                  : 'Switch to dark mode',
            ),
          ],
        ),
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
                  child: StreamingTextMarkdown(
                    key: ValueKey('streaming_text_$_resetCounter'),
                    text: isArabic
                        ? '''# مرحباً بكم! 🤖

هذا **عرض توضيحي** للنص المتدفق.

يمكنك تجربة الأوضاع المختلفة:
1. حرف بحرف
2. كلمة بكلمة
3. مجموعات مخصصة

*هذا مثال بسيط* على قدراتنا في عرض النصوص العربية!'''
                        : '''# Welcome to the Future! 🤖

This is an **AI-powered** text streaming demonstration.

Explore different modes:
1. Character by character
2. Word by word
3. Custom chunks

*Experience the future* of text animation!''',
                    initialText: isArabic
                        ? '# مرحباً بكم!\n\nجاري تهيئة النظام...\n\n'
                        : '# Welcome!\n\nInitializing system...\n\n',
                    fadeInEnabled: _fadeInEnabled,
                    fadeInDuration: _fadeInDuration,
                    wordByWord: _wordByWord,
                    chunkSize: _chunkSize,
                    typingSpeed: _typingSpeed,
                    textDirection:
                        isArabic ? TextDirection.rtl : TextDirection.ltr,
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
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
                      label: isArabic ? 'كلمة بكلمة' : 'Word by Word',
                      value: _wordByWord,
                      onChanged: (value) => _updateSettings(wordByWord: value),
                    ),
                    if (!_wordByWord)
                      _buildDropdown(
                        label: isArabic ? 'حجم المجموعة' : 'Chunk Size',
                        value: _chunkSize,
                        items: [1, 2, 3, 5, 10],
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
                    if (_fadeInEnabled)
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

  Widget _buildDropdown({
    required String label,
    required int value,
    required List<int> items,
    required ValueChanged<int?> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
        DropdownButton<int>(
          value: value,
          items: items.map((size) {
            return DropdownMenuItem(value: size, child: Text('$size'));
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
