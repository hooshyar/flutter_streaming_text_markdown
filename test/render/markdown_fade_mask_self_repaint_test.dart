// Regression: after a tap-to-complete mid-stream, the last revealed
// paragraph could stay invisible. The mask arms a fade run when it first
// lays the new text out, which can be later than the reveal engine's own
// run; the widget's ticker, timed from the engine, could stop before the
// mask's run finished, freezing it at its starting alpha. The mask now
// reports whether it is still fading so its owner keeps ticking.
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_streaming_text_markdown/src/render/markdown_fade_mask.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the mask reports when it starts and stops fading', (
    tester,
  ) async {
    var clock = Duration.zero;
    final repaint = ValueNotifier<int>(0);
    addTearDown(repaint.dispose);
    final reports = <bool>[];

    Widget build(String text) => Directionality(
      textDirection: TextDirection.ltr,
      child: MarkdownFadeMask(
        enabled: true,
        epoch: 0,
        now: () => clock,
        fadeDuration: const Duration(milliseconds: 200),
        curve: Curves.linear,
        repaint: repaint,
        onFadingChanged: reports.add,
        child: Text(text),
      ),
    );

    await tester.pumpWidget(build('Hello'));
    await tester.pumpWidget(build('Hello world'));
    await tester.pump();

    final mask = tester.renderObject<RenderMarkdownFadeMask>(
      find.byType(MarkdownFadeMask),
    );
    expect(mask.debugActiveDims(), isNotEmpty);
    expect(reports, [true]);

    // Fade time passes; the owner's ticker pings `repaint` to redraw.
    clock = const Duration(milliseconds: 250);
    repaint.value++;
    await tester.pump();
    await tester.pump();

    expect(mask.debugActiveDims(), isEmpty);
    expect(reports, [true, false]);
  });

  testWidgets('a mask removed while fading reports that it stopped', (
    tester,
  ) async {
    final repaint = ValueNotifier<int>(0);
    addTearDown(repaint.dispose);
    final reports = <bool>[];

    Widget build(String text) => Directionality(
      textDirection: TextDirection.ltr,
      child: MarkdownFadeMask(
        enabled: true,
        epoch: 0,
        now: () => Duration.zero,
        fadeDuration: const Duration(milliseconds: 200),
        curve: Curves.linear,
        repaint: repaint,
        onFadingChanged: reports.add,
        child: Text(text),
      ),
    );

    await tester.pumpWidget(build('Hello'));
    await tester.pumpWidget(build('Hello world'));
    await tester.pump();
    expect(reports, [true]);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Text('gone'),
      ),
    );
    await tester.pump();
    expect(reports, [true, false]);
  });
}
