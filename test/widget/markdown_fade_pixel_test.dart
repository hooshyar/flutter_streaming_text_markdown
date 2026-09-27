// B1 final-verify round 2 BLOCKER regression test (pixel-level).
//
// Adapted from the verifier's own probes
// (scratchpad/stm/vb2/probes/mono_test.dart / pix_test.dart): the earlier
// `MarkdownFadeMask` mapped the reveal engine's fade runs onto the rendered
// paragraph by *distance from the end of the source text*, assuming the
// source and rendered texts grow in lockstep at the tail. They don't -
// `gpt_markdown` strips markdown syntax entirely, so appending `**bold**`
// or a link made EVERY older run's "distance from the end" jump too,
// mis-dimming already-settled words (down to 0.00 for a bold word, 0.06 for
// an entire line behind a long link).
//
// This test streams realistic prose containing bold, a link and inline
// code at three different chunk sizes and, using a real `RepaintBoundary
// .toImage()` snapshot per frame (no reliance on `debugActiveDims` - this
// is the pixel-level probe verify actually failed on), asserts that no
// already-settled word's ink alpha ever drops once it's reached near-full
// darkness, and that the newest word keeps rising monotonically to full
// darkness. It FAILS against the pre-fix `MarkdownFadeMask` (source-offset
// mapping, commit 11e38fe / integration HEAD daeceac) and PASSES after the
// rendered-length-based rewrite.
@Timeout(Duration(seconds: 600))
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

final _key = GlobalKey();

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    backgroundColor: Colors.white,
    body: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: _key,
        child: Container(color: Colors.white, width: 500, child: child),
      ),
    ),
  ),
);

class _Snap {
  _Snap(this.w, this.h, this.px);
  final int w;
  final int h;
  final Uint8List px;

  /// Mean "ink" (255 - red channel) over [r] - 0 for a blank white box,
  /// higher for darker (more opaque/settled) text.
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

/// Rects (boundary coords) of the LAST occurrence of [word] among every
/// `RenderParagraph` under the boundary.
List<Rect> _rectsOf(WidgetTester t, String word) {
  final rb = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  RenderParagraph? hit;
  var at = -1;
  void visit(RenderObject n) {
    if (n is RenderParagraph) {
      final s = n.text.toPlainText();
      final i = s.lastIndexOf(word);
      if (i >= 0) {
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

/// One real-time-paced 16ms frame - the fade clock is a real `Stopwatch`
/// (deliberately independent of the fake test clock), so `runAsync` an
/// actual delay before pumping, exactly like the plain-text
/// `smooth_fade_test.dart` file's own real-frame pumping. Pumps by the
/// ACTUAL measured elapsed real time of the delay, not a fixed nominal
/// 16ms, so a loaded machine (where the delay can genuinely take much
/// longer) never desyncs the widget tree's virtual clock from the real
/// clock the fade math itself uses - see
/// `markdown_fade_verify3_test.dart`'s `_frame` doc.
Future<void> _frame(WidgetTester t) async {
  final sw = Stopwatch()..start();
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 16)),
  );
  sw.stop();
  await t.pump(sw.elapsed);
}

const _prose =
    'Hello there friend, this is **really important** and please see '
    '[the docs](https://example.com/some/long/path/here) for more info about '
    '`fooBar` usage and stuff. Then more words follow here to finish. ';

// "and" and "more" are deliberately excluded - both appear TWICE in
// [_prose] ("...important** and please...", "...usage and stuff." /
// "for more info...", "Then more words...") and [_rectsOf] (like the
// verifier's own probe it's adapted from) locates the LAST occurrence of a
// word string, so tracking either would flip from the first instance's
// settled rect to the second, fresh instance's rect mid-stream - a test
// artifact, not a real dimming regression.
const _words = [
  'Hello',
  'friend,',
  'this',
  'really',
  'important',
  'please',
  'see',
  'the docs',
  'for',
  'info',
  'about',
  'fooBar',
  'usage',
  'stuff.',
  'Then',
  'finish.',
];

/// Streams [src] at [chunk] characters per real 16ms frame and returns, per
/// word in [words], the darkness series normalized against that word's OWN
/// final (fully-settled) darkness.
Future<Map<String, List<double>>> _streamAndSample(
  WidgetTester t,
  String src, {
  required int chunk,
}) async {
  final sc = StreamController<String>();
  await t.pumpWidget(
    _host(
      StreamingText(
        text: '',
        stream: sc.stream,
        markdownEnabled: true,
        showCursor: true,
      ),
    ),
  );
  final series = {for (final w in _words) w: <double>[]};
  var i = 0;
  var f = 0;
  while (f < 400) {
    if (i < src.length) {
      final end = (i + chunk > src.length) ? src.length : i + chunk;
      sc.add(src.substring(i, end));
      i = end;
      if (i >= src.length) unawaited(sc.close());
    }
    await _frame(t);
    f++;
    final s = await _snap(t);
    for (final w in _words) {
      series[w]!.add(_darkOf(s, _rectsOf(t, w)));
    }
    if (i >= src.length && !t.binding.hasScheduledFrame) break;
  }
  final sEnd = await _snap(t);
  final normalized = <String, List<double>>{};
  for (final w in _words) {
    final ref = _darkOf(sEnd, _rectsOf(t, w));
    normalized[w] = [
      for (final v in series[w]!) v.isNaN ? double.nan : v / ref,
    ];
  }
  await t.pumpWidget(const SizedBox());
  return normalized;
}

/// The largest drop observed in [series] AFTER it first reached [peakFloor]
/// (i.e. after the word had visually settled at least once) - 0.0 if it
/// never reached [peakFloor], or never dropped after doing so.
double _worstDropAfterSettling(List<double> series, {double peakFloor = 0.9}) {
  var peak = 0.0;
  var drop = 0.0;
  for (final v in series) {
    if (v.isNaN) continue;
    if (v > peak) peak = v;
    if (peak >= peakFloor && peak - v > drop) drop = peak - v;
  }
  return drop;
}

void main() {
  group('B1 verify-round-2: markdown fade must never dim settled words', () {
    for (final chunk in [3, 12, 40]) {
      testWidgets(
        'prose with bold/link/inline-code streamed in $chunk-char chunks: '
        'settled words never drop >0.05, newest word rises to 1.0',
        (tester) async {
          final series = await _streamAndSample(tester, _prose, chunk: chunk);

          final offenders = <String>[];
          for (final entry in series.entries) {
            final drop = _worstDropAfterSettling(entry.value);
            if (drop > 0.05) {
              offenders.add(
                '${entry.key} drop=${drop.toStringAsFixed(3)} '
                'seq=${entry.value.where((v) => !v.isNaN).map((v) => v.toStringAsFixed(2)).join(',')}',
              );
            }
          }
          expect(
            offenders,
            isEmpty,
            reason:
                'a settled word\'s alpha must never drop by more than 0.05 '
                'once it has reached near-full darkness:\n'
                '${offenders.join('\n')}',
          );

          // The newest word ("finish.", the very last one revealed) must
          // itself rise - monotonically, allowing tiny float noise - all
          // the way to (approximately) its own final darkness.
          final newest = series['finish.']!.where((v) => !v.isNaN).toList();
          expect(
            newest,
            isNotEmpty,
            reason: 'the newest word must have been observed fading in',
          );
          for (var i = 1; i < newest.length; i++) {
            expect(
              newest[i],
              greaterThanOrEqualTo(newest[i - 1] - 0.05),
              reason: 'the newest word\'s alpha must rise (sample $i): $newest',
            );
          }
          expect(
            newest.last,
            closeTo(1.0, 0.05),
            reason: 'the newest word must settle to fully opaque: $newest',
          );
        },
      );
    }
  });
}
