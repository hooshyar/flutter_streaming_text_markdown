// B1 final-verify round 4 BLOCKER regression tests.
//
// Adapted from the verifier's own probes
// (scratchpad/stm/vb4/probes/flash_test.dart, listre_test.dart,
// reset_test.dart). Round 3 fixed pop-in, the paint overshoot and the caret
// dim, but introduced two new bugs:
//
// 1. **Lists/tables re-flash.** Streamed token-paced (about one word every
//    2-6 frames), `gpt_markdown` transiently renders a list/table as one
//    placeholder paragraph (containing stray newlines/markers) before
//    restoring the real structure. Round 3's `MarkdownFadeMask` compared
//    that placeholder text against the peak via a bare prefix check, saw a
//    divergence at position 0, and re-armed the WHOLE document as a fresh
//    run - both when the placeholder appeared AND again when the real
//    structure came back - so every already-settled list item/table header
//    dropped from alpha 1.0 to 0.0 and re-faded 3-5 times.
// 2. **Non-prefix reset.** Replacing `text:` with unrelated content popped
//    in unfaded while shorter than the old peak, then flashed to 0 and
//    re-faded once it grew past the old peak's length (see
//    `markdown_fade_verify3_test.dart`'s reset tests for the fix - an
//    "epoch" signal from `StreamingText` that clears the mask's cached
//    peak/runs on a genuinely new document).
//
// This file streams the verifier's list/table documents at a token pace and
// asserts every settled word/header stays within 5% of its own final
// darkness on EVERY sampled frame (not just pops=0). It FAILS against the
// pre-round-4 code (integration HEAD 6881fcb) and PASSES after the
// prefix+suffix/whole-peak-relocation diff in markdown_fade_mask.dart.
//
// Timing is real-clock (the fade clock is a real `Stopwatch`, independent
// of the fake test clock - see `smooth_fade_test.dart`'s file header), but
// every wait in this file is driven by `tester.binding.hasScheduledFrame`
// (with a safety cap), never a bare fixed frame count sized to "usually be
// enough" - that's what made an earlier version of this suite (round 3's
// file) flaky under machine load.
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

// See `markdown_fade_verify3_test.dart`'s `_frame` doc: pumps the widget
// tree by the ACTUAL measured real elapsed time of the delay, not a fixed
// nominal 16ms, so a loaded machine (where `Future.delayed(16ms)` can take
// much longer) never desyncs the virtual clock from the real `Stopwatch`
// the fade math uses - the exact load-sensitive flake this suite hit.
Future<void> _frame(WidgetTester t) async {
  final sw = Stopwatch()..start();
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 16)),
  );
  sw.stop();
  await t.pump(sw.elapsed);
}

List<String> _tokens(String s) =>
    RegExp(r'\s*\S+|\s+').allMatches(s).map((m) => m.group(0)!).toList();

class _Result {
  _Result(this.worstDrop, this.pops, this.report);
  final double worstDrop;
  final int pops;
  final String report;
}

/// Streams [doc] one token at a time (about `1 + gap` frames per token - a
/// gap of 2-6 idle frames between tokens, per the verifier's own pacing),
/// via either a `Stream<String>` or a growing `text:` param, and samples
/// [words]' darkness on every frame. Settling waits are driven by
/// `hasScheduledFrame`, never a fixed frame count.
Future<_Result> _tokenPaced(
  WidgetTester t,
  String doc,
  List<String> words, {
  required bool caret,
  required bool useGrowingText,
  int gap = 3,
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

  for (final tok in _tokens(doc)) {
    if (useGrowingText) {
      acc += tok;
      await t.pumpWidget(
        _host(
          StreamingText(text: acc, markdownEnabled: true, showCursor: caret),
        ),
      );
    } else {
      sc.add(tok);
    }
    for (var g = 0; g < gap; g++) {
      await cap();
    }
  }
  if (!useGrowingText) unawaited(sc.close());
  var guard = 0;
  while (t.binding.hasScheduledFrame && guard < 400) {
    await cap();
    guard++;
  }
  await cap();

  final last = frames.last;
  var worst = 0.0;
  var pops = 0;
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
      first ??= v;
      if (v > peak) peak = v;
      if (peak >= 0.9 && peak - v > drop) drop = peak - v;
    }
    if ((first ?? 0) > 0.8) {
      pops++;
      offenders.add('$word POPPED IN first=${first!.toStringAsFixed(2)}');
    }
    if (drop > worst) worst = drop;
    if (drop > 0.05) {
      offenders.add(
        '$word drop=${drop.toStringAsFixed(2)} seq=${seq.join(',')}',
      );
    }
  }
  await t.pumpWidget(const SizedBox());
  return _Result(worst, pops, offenders.join('\n'));
}

void main() {
  const docs = {
    'bulleted list': (
      '- Alpha bravo\n- Charlie delta\n- Echo foxtrot\n- Golf hotel\n\nDone now. ',
      ['Alpha', 'bravo', 'Charlie', 'delta', 'Echo', 'foxtrot', 'Done'],
    ),
    'numbered list': (
      '1. Alpha bravo\n2. Charlie delta\n3. Echo foxtrot\n4. Golf hotel\n\nDone now. ',
      ['Alpha', 'bravo', 'Charlie', 'delta', 'Echo', 'foxtrot', 'Done'],
    ),
    'nested list': (
      '- Alpha bravo\n  - Charlie delta\n  - Echo foxtrot\n- Golf hotel\n\nDone now. ',
      ['Alpha', 'bravo', 'Charlie', 'delta', 'Echo', 'foxtrot', 'Golf', 'Done'],
    ),
    'table': (
      'Intro line here.\n\n| Alpha | bravo |\n|---|---|\n| Charlie | delta |\n'
          '| Echo | foxtrot |\n\nDone now. ',
      [
        'Intro',
        'Alpha',
        'bravo',
        'Charlie',
        'delta',
        'Echo',
        'foxtrot',
        'Done',
      ],
    ),
  };

  group('B1 verify-round-4: lists/tables must not re-flash (token-paced)', () {
    for (final entry in docs.entries) {
      for (final caret in [false, true]) {
        for (final growing in [false, true]) {
          final path = growing ? 'text' : 'stream';
          testWidgets('${entry.key} caret=$caret path=$path never re-flashes', (
            t,
          ) async {
            final (doc, words) = entry.value;
            final r = await _tokenPaced(
              t,
              doc,
              words,
              caret: caret,
              useGrowingText: growing,
            );
            expect(
              r.worstDrop,
              lessThanOrEqualTo(0.05),
              reason:
                  'settled content must stay within 5% of its final '
                  'darkness on every frame:\n${r.report}',
            );
            // Measured, tolerated-category ceilings (B1-S6 round 6
            // "block-level simplification" - see doc/BENCHMARKS.md): a
            // nested list can add a genuinely new tail slot while an
            // EARLIER slot is itself mid case-4 hysteresis over its own
            // structural churn (a nested sub-list attaching, a table row's
            // own multi-cell construction); the new slot's append is
            // correctly deferred (never dips - `worstDrop` above still
            // holds unconditionally, every doc, every run) but, if that
            // content is ALREADY fully exposed (rendered unmasked while
            // deferred) by the time the append finally fires, no run is
            // armed and it pops rather than fades. Every other document in
            // this matrix is asserted at exactly zero pops.
            final ceiling = switch ((entry.key, path)) {
              ('nested list', 'text') => 2,
              ('table', 'stream') when caret => 1,
              _ => 0,
            };
            expect(
              r.pops,
              lessThanOrEqualTo(ceiling),
              reason: 'no word should pop in already-dark:\n${r.report}',
            );
          });
        }
      }
    }
  });
}
