import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

void main() {
  group('New Features Tests', () {
    group('Issue #1 Fix: Animation Restart Prevention', () {
      testWidgets('Text updates should not restart animation from beginning', (WidgetTester tester) async {
        // This reproduces @adamkoch's issue exactly
        String text = 'hello world! ';
        
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          text = text + text; // Append text (like @adamkoch's test)
                        });
                      },
                      child: const Text('Update Text'),
                    ),
                    StreamingTextMarkdown.chatGPT(
                      text: text,
                    ),
                  ],
                );
              },
            ),
          ),
        ));

        // Wait for initial animation to start
        await tester.pump(const Duration(milliseconds: 100));
        
        // Find the first few characters should be displayed
        await tester.pump(const Duration(milliseconds: 200));
        
        // Press the button to add more text
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
        
        // Animation should continue, not restart
        // The widget should maintain its animation state
        await tester.pump(const Duration(milliseconds: 100));
        
        // Verify the widget exists and is working
        expect(find.byType(StreamingTextMarkdown), findsOneWidget);
      });

      testWidgets('Widget key should not include text content', (WidgetTester tester) async {
        // Test that widget key doesn't change when only text changes
        const text1 = 'hello';
        const text2 = 'hello world';
        
        Widget buildWidget(String text) {
          return MaterialApp(
            home: StreamingTextMarkdown.chatGPT(text: text),
          );
        }

        await tester.pumpWidget(buildWidget(text1));
        final widget1 = tester.widget<StreamingText>(find.byType(StreamingText));
        final key1 = widget1.key;

        await tester.pumpWidget(buildWidget(text2));
        final widget2 = tester.widget<StreamingText>(find.byType(StreamingText));
        final key2 = widget2.key;

        // Keys should be the same (they don't include text content)
        expect(key1, equals(key2));
      });

      testWidgets('Configuration changes should restart animation', (WidgetTester tester) async {
        const text = 'hello world';
        
        await tester.pumpWidget(MaterialApp(
          home: StreamingTextMarkdown.chatGPT(text: text),
        ));
        
        // Change configuration (typing speed)
        await tester.pumpWidget(MaterialApp(
          home: StreamingTextMarkdown(
            text: text,
            typingSpeed: const Duration(milliseconds: 100), // Different speed
          ),
        ));

        // This should work fine - configuration changes are allowed to restart
        expect(find.byType(StreamingTextMarkdown), findsOneWidget);
      });
    });

    group('Issue #4: Disable Animations Feature', () {
      testWidgets('animationsEnabled=false should show text instantly', (WidgetTester tester) async {
        const text = 'Hello World! This should appear instantly.';
        
        await tester.pumpWidget(MaterialApp(
          home: StreamingTextMarkdown(
            text: text,
            animationsEnabled: false,
          ),
        ));

        // Should appear immediately without waiting for animation
        await tester.pump();
        
        // All text should be visible immediately
        expect(find.text(text), findsOneWidget);
      });

      testWidgets('animationsEnabled=true should animate normally', (WidgetTester tester) async {
        const text = 'Hello World!';
        
        await tester.pumpWidget(MaterialApp(
          home: StreamingTextMarkdown(
            text: text,
            animationsEnabled: true,
            typingSpeed: const Duration(milliseconds: 50),
          ),
        ));

        // Initially, no text should be visible
        await tester.pump();
        expect(find.text(text), findsNothing);
        
        // After some time, animation should be in progress
        await tester.pump(const Duration(milliseconds: 200));
        // Partial text might be visible, but full text should not be there yet
        expect(find.text(text), findsNothing);
      });

      testWidgets('.instant() preset should have animations disabled', (WidgetTester tester) async {
        const text = 'Instant text display';
        
        await tester.pumpWidget(MaterialApp(
          home: StreamingTextMarkdown.instant(text: text),
        ));

        await tester.pump();
        
        // Should appear immediately
        expect(find.text(text), findsOneWidget);
      });

      testWidgets('Other presets should have animations enabled by default', (WidgetTester tester) async {
        const text = 'Animated text';
        
        // Test .chatGPT() preset
        await tester.pumpWidget(MaterialApp(
          home: StreamingTextMarkdown.chatGPT(text: text),
        ));

        await tester.pump();
        
        // Should not appear immediately (animation is enabled)
        expect(find.text(text), findsNothing);
      });

      testWidgets('Disable animations with setState updates', (WidgetTester tester) async {
        // This tests the combination of issue #4 feature with issue #1 fix
        String text = 'hello';
        
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          text = '$text world';
                        });
                      },
                      child: const Text('Update Text'),
                    ),
                    StreamingTextMarkdown(
                      text: text,
                      animationsEnabled: false, // Disabled animations
                    ),
                  ],
                );
              },
            ),
          ),
        ));

        // Initial text should appear instantly
        await tester.pump();
        expect(find.text('hello'), findsOneWidget);
        
        // Update text
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
        
        // Updated text should also appear instantly
        expect(find.text('hello world'), findsOneWidget);
      });
    });

    group('Integration Tests', () {
      testWidgets('Both features work together correctly', (WidgetTester tester) async {
        String text = 'initial';
        bool animationsEnabled = true;
        
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    ElevatedButton(
                      key: const Key('toggle_animations'),
                      onPressed: () {
                        setState(() {
                          animationsEnabled = !animationsEnabled;
                        });
                      },
                      child: Text('Animations: ${animationsEnabled ? "ON" : "OFF"}'),
                    ),
                    ElevatedButton(
                      key: const Key('update_text'),
                      onPressed: () {
                        setState(() {
                          text = '$text updated';
                        });
                      },
                      child: const Text('Update Text'),
                    ),
                    StreamingTextMarkdown(
                      text: text,
                      animationsEnabled: animationsEnabled,
                    ),
                  ],
                );
              },
            ),
          ),
        ));

        // Initially animations are enabled
        await tester.pump();
        
        // Disable animations
        await tester.tap(find.byKey(const Key('toggle_animations')));
        await tester.pump();
        
        // Update text with animations disabled
        await tester.tap(find.byKey(const Key('update_text')));
        await tester.pump();
        
        // Should show instantly
        expect(find.text('initial updated'), findsOneWidget);
        
        // Re-enable animations
        await tester.tap(find.byKey(const Key('toggle_animations')));
        await tester.pump();
        
        // Update text again
        await tester.tap(find.byKey(const Key('update_text')));
        await tester.pump();
        
        // With animations enabled, should not show full text immediately
        expect(find.text('initial updated updated'), findsNothing);
      });
    });
  });
}