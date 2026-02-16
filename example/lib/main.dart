import 'package:flutter/material.dart';
import 'widgets/hero_section.dart';
import 'widgets/playground.dart';
import 'widgets/feature_cards.dart';
import 'widgets/footer.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _dark = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_streaming_text_markdown',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: _dark ? Brightness.dark : Brightness.light,
        colorSchemeSeed: const Color(0xFF00BCD4),
        scaffoldBackgroundColor: _dark ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: Icon(_dark ? Icons.light_mode : Icons.dark_mode, size: 20),
                      onPressed: () => setState(() => _dark = !_dark),
                    ),
                  ),
                  const HeroSection(),
                  const Playground(),
                  const FeatureCards(),
                  const SizedBox(height: 24),
                  const DemoFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
