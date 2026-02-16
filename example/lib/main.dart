import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'sections/hero_section.dart';
import 'sections/presets_section.dart';
import 'sections/features_section.dart';
import 'sections/controller_section.dart';
import 'sections/customization_section.dart';
import 'sections/theme_section.dart';
import 'sections/footer_section.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  bool _isDark = true;
  StreamingTextConfig? _activePreset;
  String? _activePresetName;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00BCD4),
          brightness: Brightness.light,
        ),
        extensions: const [
          StreamingTextTheme(
            textStyle: TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF212121)),
            markdownStyleSheet: TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF212121)),
            defaultPadding: EdgeInsets.zero,
          ),
        ],
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00BCD4),
          brightness: Brightness.dark,
        ),
        extensions: const [
          StreamingTextTheme(
            textStyle: TextStyle(fontSize: 14, height: 1.6, color: Color(0xFFE0E0E0)),
            markdownStyleSheet: TextStyle(fontSize: 14, height: 1.6, color: Color(0xFFE0E0E0)),
            defaultPadding: EdgeInsets.zero,
          ),
        ],
      ),
      home: Scaffold(
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 840),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HeroSection(
                          activePreset: _activePreset,
                          activePresetName: _activePresetName,
                        ),
                        PresetsSection(
                          onPresetSelected: (result) {
                            setState(() {
                              _activePreset = result.$1;
                              _activePresetName = result.$2;
                            });
                          },
                        ),
                        const FeaturesSection(),
                        const ControllerSection(),
                        const CustomizationSection(),
                        const ThemeSection(),
                        const FooterSection(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Dark/light toggle
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => setState(() => _isDark = !_isDark),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isDark ? Colors.white10 : Colors.black12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isDark ? Icons.light_mode : Icons.dark_mode,
                      size: 18,
                      color: _isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
