// B1 final-verify round 3 BLOCKER regression tests.
//
// Adapted from the verifier's own probes
// (scratchpad/stm/vb3/probes/pop_test.dart, chatui2_test.dart, caret_test.dart,
// gapid_test.dart): round 2's `MarkdownFadeMask` tracked only the LAST
// `RenderParagraph`'s own rendered growth and reset all tracking to empty
// whenever that paragraph's IDENTITY changed. `gpt_markdown` changes that
// identity constantly - every new list item, table cell, code line, quote,
// and even every rebuild of a plain, continuously-growing top-level
// paragraph - so most content popped in fully opaque instead of fading, and
// the run's range still included the caret's own trailing placeholder
// character (dimming the caret with every word).
//
// This file streams each of those block-type scenarios and, using real
// `RepaintBoundary.toImage()` pixel snapshots, asserts:
// - the newest word never appears already-dark on its very first visible
//   frame (a "pop" instead of a fade);
// - once a word has reached near-full darkness, it never dips more than a
//   small tolerance (already-settled text must never dip);
// - the caret's own darkness never dips when a new word is revealed next
//   to it.
//
// It FAILS against the pre-round-3 code (integration HEAD b918c7e) and
// PASSES after the global-offset-space rewrite in markdown_fade_mask.dart.
@Timeout(Duration(seconds: 900))
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

final _key = GlobalKey();

Widget _host(Widget c) => MaterialApp(
  home: Scaffold(
    backgroundColor: Colors.white,
    body: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: _key,
        child: Container(color: Colors.white, width: 500, child: c),
      ),
    ),
  ),
);

class _Snap {
  _Snap(this.w, this.h, this.px);
  final int w;
  final int h;
  final Uint8List px;

  double dark(Rect r) {
    var sum = 0.0;
    var n = 0;
    for (var y = r.top.floor(); y < r.bottom.ceil(); y++) {
      for (var x = r.left.floor(); x < r.right.ceil(); x++) {
        if (x < 0 || y < 0 || x >= w || y >= h) continue;
        final i = (y * w + x) * 4;
        sum += 255 - px[i];
        n++;
      }
    }
    return n == 0 ? 0 : sum / n;
  }
}

Future<_Snap> _snap(WidgetTester t) async {
  final rb = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await t.runAsync(() async {
    final img = await rb.toImage();
    final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final s = _Snap(img.width, img.height, bd!.buffer.asUint8List());
    img.dispose();
    return s;
  }))!;
}

/// Rects of the FIRST occurrence of [word] among every `RenderParagraph`
/// under the boundary (matches the verifier's `pop_test.dart` - it looks
/// for the first, not the last, occurrence).
List<Rect> _rectsOf(WidgetTester t, String word) {
  final rb = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  RenderParagraph? hit;
  var at = -1;
  void visit(RenderObject n) {
    if (n is RenderParagraph) {
      final s = n.text.toPlainText();
      final i = s.indexOf(word);
      if (i >= 0 && hit == null) {
        hit = n;
        at = i;
      }
    }
    n.visitChildren(visit);
  }

  visit(rb);
  final h = hit;
  if (h == null) return const [];
  final boxes = h.getBoxesForSelection(
    TextSelection(baseOffset: at, extentOffset: at + word.length),
  );
  final tr = h.getTransformTo(rb);
  return [for (final bx in boxes) MatrixUtils.transformRect(tr, bx.toRect())];
}

double _darkOf(_Snap s, List<Rect> rs) {
  if (rs.isEmpty) return double.nan;
  var tot = 0.0;
  for (final r in rs) {
    tot += s.dark(r);
  }
  return tot / rs.length;
}

Future<void> _frame(WidgetTester t) async {
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 16)),
  );
  await t.pump(const Duration(milliseconds: 16));
}

class _Result {
  _Result(this.pops, this.words, this.worstDrop, this.report);
  final int pops;
  final int words;
  final double worstDrop;
  final String report;
}

/// Streams [segments] (each a list of chunks sent as one `StreamController
/// .add`), idling [gap] frames between segments, and reports: how many of
/// [words] "popped in" (already >80% dark the first frame they're visible)
/// and the worst drop any word suffered after reaching near-full darkness.
Future<_Result> _run(
  WidgetTester t,
  List<String> segments,
  List<String> words, {
  bool caret = false,
  int chunk = 3,
  int gap = 0,
  bool useGrowingText = false,
}) async {
  final sc = StreamController<String>();
  var acc = '';
  if (!useGrowingText) {
    await t.pumpWidget(
      _host(
        StreamingText(
          text: '',
          stream: sc.stream,
          markdownEnabled: true,
          showCursor: caret,
        ),
      ),
    );
  }
  final frames = <_Snap>[];
  final rects = <Map<String, List<Rect>>>[];
  Future<void> cap() async {
    await _frame(t);
    frames.add(await _snap(t));
    rects.add({for (final w in words) w: _rectsOf(t, w)});
  }

  for (final seg in segments) {
    for (var i = 0; i < seg.length; i += chunk) {
      final end = (i + chunk > seg.length) ? seg.length : i + chunk;
      final piece = seg.substring(i, end);
      if (useGrowingText) {
        acc += piece;
        await t.pumpWidget(
          _host(
            StreamingText(text: acc, markdownEnabled: true, showCursor: caret),
          ),
        );
      } else {
        sc.add(piece);
      }
      await cap();
    }
    for (var g = 0; g < gap; g++) {
      await cap();
    }
  }
  if (!useGrowingText) unawaited(sc.close());
  for (var g = 0; g < 40; g++) {
    await cap();
  }

  final last = frames.last;
  var pops = 0;
  var worstDrop = 0.0;
  final offenders = <String>[];
  for (final word in words) {
    final ref = _darkOf(last, _rectsOf(t, word));
    double? first;
    var peak = 0.0;
    var drop = 0.0;
    final seq = <String>[];
    for (var f = 0; f < frames.length; f++) {
      final r = rects[f][word]!;
      if (r.isEmpty) continue;
      final v = _darkOf(frames[f], r) / ref;
      seq.add(v.toStringAsFixed(2));
      if (first == null && v > 0.03) first = v;
      if (v > peak) peak = v;
      if (peak >= 0.9 && peak - v > drop) drop = peak - v;
    }
    if ((first ?? 0) > 0.8) pops++;
    if (drop > worstDrop) worstDrop = drop;
    if (drop > 0.05) {
      offenders.add(
        '$word drop=${drop.toStringAsFixed(2)} seq=${seq.join(',')}',
      );
    }
  }
  await t.pumpWidget(const SizedBox());
  return _Result(pops, words.length, worstDrop, offenders.join('\n'));
}

void main() {
  group('B1 verify-round-3: block-type pop-in / settle-never-dips', () {
    const prose =
        'Alpha bravo charlie delta echo foxtrot golf hotel india juliet kilo lima. ';
    const proseWords = [
      'Alpha',
      'bravo',
      'charlie',
      'delta',
      'echo',
      'foxtrot',
      'golf',
      'hotel',
      'india',
      'juliet',
      'kilo',
      'lima.',
    ];

    for (final caret in [false, true]) {
      testWidgets('continuous prose caret=$caret never pops, never dips', (
        t,
      ) async {
        final r = await _run(t, [prose], proseWords, caret: caret);
        expect(r.pops, 0, reason: 'words popped in unfaded: caret=$caret');
        expect(r.worstDrop, lessThanOrEqualTo(0.05), reason: r.report);
      });

      testWidgets('new paragraph after an idle gap caret=$caret', (t) async {
        final r = await _run(
          t,
          ['Alpha bravo ', 'charlie ', 'delta ', 'echo '],
          ['charlie', 'delta', 'echo'],
          caret: caret,
          gap: 40,
        );
        expect(r.pops, 0, reason: 'gap-revealed words popped in: caret=$caret');
        expect(r.worstDrop, lessThanOrEqualTo(0.05), reason: r.report);
      });

      testWidgets('a new list item caret=$caret', (t) async {
        final r = await _run(
          t,
          ['- Alpha bravo\n- Charlie delta\n- Echo foxtrot\n'],
          ['Alpha', 'bravo', 'Charlie', 'delta', 'Echo', 'foxtrot'],
          caret: caret,
        );
        expect(r.pops, 0, reason: 'list items popped in: caret=$caret');
        expect(r.worstDrop, lessThanOrEqualTo(0.05), reason: r.report);
      });

      testWidgets('a block quote caret=$caret', (t) async {
        final r = await _run(
          t,
          ['Intro words.\n\n> Quoted alpha bravo\n\nAfter quote. '],
          ['Intro', 'Quoted', 'bravo', 'After', 'quote.'],
          caret: caret,
        );
        expect(r.pops, 0, reason: 'quote text popped in: caret=$caret');
        expect(r.worstDrop, lessThanOrEqualTo(0.05), reason: r.report);
      });

      testWidgets('a table cell, and text after the table, caret=$caret', (
        t,
      ) async {
        final r = await _run(
          t,
          [
            'Intro words.\n\n| Aa | Bb |\n|---|---|\n'
                '| alphacell | bravocell |\n| charliecell | deltacell |\n\n'
                'After table. ',
          ],
          [
            'Intro',
            'alphacell',
            'bravocell',
            'charliecell',
            'deltacell',
            'After',
            'table.',
          ],
          caret: caret,
        );
        expect(r.pops, 0, reason: 'table cells popped in: caret=$caret');
        expect(r.worstDrop, lessThanOrEqualTo(0.05), reason: r.report);
      });

      testWidgets('a code line, and text after the code block, caret=$caret', (
        t,
      ) async {
        final r = await _run(
          t,
          [
            'Intro words.\n\n```\nfirstline here\nsecondline here\n```\n\n'
                'After code. ',
          ],
          ['Intro', 'firstline', 'secondline', 'After', 'code.'],
          caret: caret,
        );
        expect(r.pops, 0, reason: 'code lines popped in: caret=$caret');
        expect(r.worstDrop, lessThanOrEqualTo(0.05), reason: r.report);
      });

      testWidgets('mid-stream bold/link/inline-code never dip caret=$caret', (
        t,
      ) async {
        final r = await _run(
          t,
          [
            'Alpha **bravo charlie** delta [echo link](https://example.com/x/y) '
                'foxtrot `golfcode` hotel. ',
          ],
          [
            'Alpha',
            'bravo',
            'charlie',
            'delta',
            'foxtrot',
            'golfcode',
            'hotel.',
          ],
          caret: caret,
        );
        expect(r.worstDrop, lessThanOrEqualTo(0.05), reason: r.report);
      });
    }

    testWidgets('a growing text: param (no Stream) never pops', (t) async {
      final r = await _run(
        t,
        ['Alpha bravo ', 'charlie delta ', 'echo foxtrot golf. '],
        ['bravo', 'charlie', 'delta', 'echo', 'foxtrot', 'golf.'],
        useGrowingText: true,
      );
      expect(r.pops, 0, reason: 'growing-text words popped in: ${r.report}');
      expect(r.worstDrop, lessThanOrEqualTo(0.05), reason: r.report);
    });

    testWidgets('non-prefix setSource never dims settled text', (t) async {
      final sc = StreamController<String>();
      await t.pumpWidget(
        _host(
          StreamingText(
            text: '',
            stream: sc.stream,
            markdownEnabled: true,
            showCursor: false,
          ),
        ),
      );
      sc.add('Alpha bravo charlie ');
      for (var i = 0; i < 30; i++) {
        await _frame(t);
      }
      final before = _darkOf(await _snap(t), _rectsOf(t, 'Alpha'));

      // A non-append replacement (StreamingText with a brand new `text:`)
      // is the render-tree-level equivalent of the engine's non-prefix
      // `setSource` - a completely different document.
      await t.pumpWidget(
        _host(
          const StreamingText(
            text: 'Totally different content here now.',
            markdownEnabled: true,
            showCursor: false,
            revealMode: RevealMode.instant,
          ),
        ),
      );
      for (var i = 0; i < 60; i++) {
        await _frame(t);
      }
      final afterAlpha = _darkOf(await _snap(t), _rectsOf(t, 'Totally'));
      expect(
        afterAlpha,
        greaterThan(0.9 * (before.isNaN ? 1.0 : before)),
        reason: 'the new document must not be left dimmed after a reset',
      );
      unawaited(sc.close());
      await t.pumpWidget(const SizedBox());
    });
  });

  group('B1 verify-round-3: caret must not dim with each new word', () {
    for (final md in [true, false]) {
      testWidgets('caret darkness stays stable, markdownEnabled=$md', (
        t,
      ) async {
        final sc = StreamController<String>();
        await t.pumpWidget(
          _host(
            StreamingText(
              text: '',
              stream: sc.stream,
              markdownEnabled: md,
              showCursor: true,
              cursorColor: Colors.black,
            ),
          ),
        );
        const words = ['Alpha', 'Bravo', 'Charlie', 'Delta', 'Echo'];
        final caretSamples = <double>[];
        for (final w in words) {
          sc.add('$w ');
          for (var f = 0; f < 10; f++) {
            await _frame(t);
            final rb =
                _key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            RenderParagraph? para;
            void visit(RenderObject n) {
              if (n is RenderParagraph &&
                  n.text.toPlainText().contains('Alpha')) {
                para = n;
              }
              n.visitChildren(visit);
            }

            visit(rb);
            final pr = para;
            if (pr == null) continue;
            final txt = pr.text.toPlainText();
            final ci = txt.lastIndexOf('￼');
            if (ci < 0) continue;
            final boxes = pr.getBoxesForSelection(
              TextSelection(baseOffset: ci, extentOffset: ci + 1),
            );
            if (boxes.isEmpty) continue;
            final tr = pr.getTransformTo(rb);
            final rect = MatrixUtils.transformRect(tr, boxes.first.toRect());
            final s = await _snap(t);
            caretSamples.add(s.dark(rect));
          }
        }
        unawaited(sc.close());
        for (var i = 0; i < 20; i++) {
          await _frame(t);
        }
        await t.pumpWidget(const SizedBox());

        // The caret pulses on its own clock between 35% and 100% opacity
        // (`caretPulseMinOpacity`) - fine, and not what's being asserted
        // here. A run wrongly covering the caret's own placeholder
        // character (verify round 3's bug) would multiply that down much
        // further every time a fresh word arrives, so no sample should
        // ever fall meaningfully below the natural pulse floor relative to
        // the brightest sample observed.
        expect(caretSamples, isNotEmpty);
        final maxSample = caretSamples.reduce((a, b) => a > b ? a : b);
        final offenders = [
          for (final v in caretSamples)
            if (v < 0.30 * maxSample) v,
        ];
        expect(
          offenders,
          isEmpty,
          reason:
              'caret darkness dipped well below its natural pulse floor '
              '(max=$maxSample): $offenders\nall samples: $caretSamples',
        );
      });
    }
  });
}
