// Strict per-word-occurrence fade invariant harness (B1-S6 round 6 "block-
// level simplification"). Ported from the round-6 verifier's own probe
// (`scratchpad/stm/vb6/probes/inv_lib.dart`), which the lead's directive
// named explicitly as the harness to port.
//
// For every tracked word OCCURRENCE (word, nth-occurrence-in-doc) found in
// the render tree, sampled every real 16ms frame:
//  - the first frame it's rendered, its darkness ratio (vs. the final,
//    fully-settled darkness) must be < 0.3 - a "pop" is anything >= 0.3;
//  - frame-to-frame darkness must never DROP by more than 0.05 (relative to
//    final darkness) - the "settled text never dips" hard invariant;
//  - the final render must pixel-match a bare `RevealMode.instant` render of
//    the same document (proves the mask never permanently alters content,
//    only its transient opacity).
//
// Pops are asserted at exactly ZERO by default. A pop is only tolerated for
// content this slice's design (see `markdown_fade_mask.dart`'s class doc,
// case 4) documents as poppable, or a specific, measured, still-open
// limitation (nested/table docs; inline-markup-heavy chat-path prose) - see
// `go()`'s own doc for [maxPopFraction] and doc/BENCHMARKS.md's "block-level
// simplification" section for the real, measured per-type numbers.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';

final _key = GlobalKey();

Widget host(Widget c) => MaterialApp(
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

class Snap {
  Snap(this.w, this.h, this.px);
  final int w, h;
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

Future<Snap> snap(WidgetTester t) async {
  final rb = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await t.runAsync(() async {
    final img = await rb.toImage();
    final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final s = Snap(img.width, img.height, bd!.buffer.asUint8List());
    img.dispose();
    return s;
  }))!;
}

/// One real-time-paced frame. Pumps the widget tree by the ACTUAL measured
/// real elapsed time of the delay (via a real `Stopwatch`), not a fixed
/// nominal 16ms - the fade clock (`StreamingText`'s own `_fadeClock`) is a
/// real `Stopwatch` too, independent of the fake test clock, so under
/// machine load a plain `Future.delayed(16ms)` can genuinely take much
/// longer; pumping a mismatched fixed nominal duration in that case desyncs
/// the widget tree's virtual clock from the real clock the fade math
/// actually uses. This is deliberately load-robust rather than relying on a
/// wall-clock threshold - see `markdown_fade_verify3_test.dart`'s `_frame`.
Future<void> frame(WidgetTester t) async {
  final sw = Stopwatch()..start();
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 16)),
  );
  sw.stop();
  await t.pump(sw.elapsed);
}

/// Rects of every tracked occurrence, in one tree walk.
Map<(String, int), List<Rect>> occRects(WidgetTester t, Set<String> words) {
  final rb = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final seen = <String, int>{};
  final out = <(String, int), List<Rect>>{};
  final re = RegExp(r'[A-Za-z]{3,}');
  void visit(RenderObject node) {
    if (node is RenderParagraph) {
      final s = node.text.toPlainText();
      Matrix4? tr;
      for (final m in re.allMatches(s)) {
        final w = m.group(0)!;
        if (!words.contains(w)) continue;
        final n = seen[w] ?? 0;
        seen[w] = n + 1;
        tr ??= node.getTransformTo(rb);
        final boxes = node.getBoxesForSelection(
          TextSelection(baseOffset: m.start, extentOffset: m.end),
        );
        out[(w, n)] = [
          for (final b in boxes) MatrixUtils.transformRect(tr, b.toRect()),
        ];
      }
    }
    node.visitChildren(visit);
  }

  visit(rb);
  return out;
}

double darkOf(Snap s, List<Rect> rs) {
  if (rs.isEmpty) return double.nan;
  var tot = 0.0;
  for (final r in rs) {
    tot += s.dark(r);
  }
  return tot / rs.length;
}

List<String> toks(String s) =>
    RegExp(r'\s*\S+|\s+').allMatches(s).map((m) => m.group(0)!).toList();

class Result {
  int pops = 0, dips = 0, words = 0;
  double worstDip = 0, worstFirst = 0;
  final details = <String>[];
}

Result analyse(
  List<Snap> frames,
  List<Map<(String, int), List<Rect>>> rects,
  Snap last,
  Map<(String, int), List<Rect>> lastRects,
) {
  final r = Result();
  for (final k in lastRects.keys) {
    final ref = darkOf(last, lastRects[k]!);
    if (!(ref > 5)) continue;
    r.words++;
    double? first;
    double? prev;
    var worst = 0.0;
    var worstAt = -1;
    final seq = <double>[];
    for (var f = 0; f < frames.length; f++) {
      final rr = rects[f][k];
      if (rr == null || rr.isEmpty) {
        prev = null; // not rendered this frame (withheld) - not a dip
        continue;
      }
      final v = darkOf(frames[f], rr) / ref;
      seq.add(v);
      first ??= v;
      if (prev != null && prev - v > worst) {
        worst = prev - v;
        worstAt = seq.length - 1;
      }
      prev = v;
    }
    final isPop = (first ?? 0) >= 0.3;
    final isDip = worst > 0.05;
    if (isPop) r.pops++;
    if (isDip) r.dips++;
    if (worst > r.worstDip) r.worstDip = worst;
    if ((first ?? 0) > r.worstFirst) r.worstFirst = first ?? 0;
    if (isPop || isDip) {
      final lo = worstAt < 0 ? 0 : (worstAt - 6).clamp(0, seq.length);
      final hi =
          worstAt < 0
              ? 12.clamp(0, seq.length)
              : (worstAt + 8).clamp(0, seq.length);
      r.details.add(
        '${k.$1}#${k.$2} first=${first?.toStringAsFixed(2)} '
        'dip=${worst.toStringAsFixed(2)}@$worstAt '
        'seq[$lo..]=${seq.sublist(lo, hi).map((e) => e.toStringAsFixed(2)).join(',')}',
      );
    }
  }
  return r;
}

Future<Snap> bareSnap(
  WidgetTester t,
  String doc, {
  Widget Function(String text)? build,
}) async {
  await t.pumpWidget(const SizedBox());
  await t.pumpWidget(
    host(
      build != null
          ? build(doc)
          : StreamingText(
            text: doc,
            markdownEnabled: true,
            showCursor: false,
            animationsEnabled: false,
            revealMode: RevealMode.instant,
          ),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await frame(t);
  }
  return snap(t);
}

String pixDiff(Snap a, Snap b) {
  if (a.w != b.w || a.h != b.h) return 'size ${a.w}x${a.h} vs ${b.w}x${b.h}';
  var n = 0;
  var x0 = 1 << 30, y0 = 1 << 30, x1 = -1, y1 = -1;
  for (var i = 0; i < a.px.length; i += 4) {
    if ((a.px[i] - b.px[i]).abs() > 8) {
      n++;
      final px = (i ~/ 4) % a.w, py = (i ~/ 4) ~/ a.w;
      if (px < x0) x0 = px;
      if (py < y0) y0 = py;
      if (px > x1) x1 = px;
      if (py > y1) y1 = py;
    }
  }
  return n == 0 ? '0' : '$n bbox=($x0,$y0)-($x1,$y1) size=${a.w}x${a.h}';
}

/// mode: 'stream' (token per [gap] frames), 'chunk' (3 chars per frame),
/// 'chat' (text: grows by one token per [gap] frames), 'burst' (whole doc at
/// once).
///
/// Asserts the hard invariant (settled text never dips >0.05) UNCONDITIONALLY
/// - that must hold for every doc/mode/caret combination, no exceptions,
/// since it's structurally guaranteed by `markdown_fade_mask.dart`'s
/// settled-length floor.
///
/// Pops are asserted at exactly ZERO by default (B1F1 round 7: a prior
/// version of this harness weakened this to a tolerance that could never
/// fail - `lessThanOrEqualTo(r.words)` - which is never acceptable; a real
/// bound belongs here, and a genuine, still-unfixed limitation belongs in
/// doc/BENCHMARKS.md, not in a defanged assertion). [maxPopFraction]
/// widens that bound ONLY for call sites that document, with real
/// measured numbers, why zero isn't currently achievable:
/// - `nested`/`table` docs (this design's block-level slot model defers a
///   tail append behind a nearby slot's own structural churn, and that
///   content can already be fully exposed by the time the append fires -
///   see `markdown_fade_mask.dart`'s [_pendingExposedLength] doc);
/// - inline-markup-heavy chat-path prose (the caught-up widget can render
///   `**bold**`/`` `code` ``/`[link]` raw before a still-streaming close
///   resolves it styled - see `markdown_fade_mask.dart`'s
///   `_growthPrefixLength` doc; measured at a few percent after that fix,
///   not exactly zero in every config).
Future<Result> go(
  WidgetTester t,
  String name,
  String doc, {
  bool caret = false,
  int gap = 3,
  String mode = 'stream',
  double maxPopFraction = 0.0,
  Widget Function(Stream<String>?, String text)? build,
  Widget Function(String text)? buildBare,
}) async {
  final words =
      RegExp(r'[A-Za-z]{3,}').allMatches(doc).map((m) => m.group(0)!).toSet();
  final sc = StreamController<String>();
  Widget mk(Stream<String>? s, String text) =>
      build != null
          ? build(s, text)
          : StreamingText(
            text: text,
            stream: s,
            markdownEnabled: true,
            showCursor: caret,
          );
  if (mode != 'chat') {
    await t.pumpWidget(host(mk(sc.stream, '')));
  }
  final frames = <Snap>[];
  final rects = <Map<(String, int), List<Rect>>>[];
  Future<void> cap() async {
    await frame(t);
    frames.add(await snap(t));
    rects.add(occRects(t, words));
  }

  if (mode == 'burst') {
    sc.add(doc);
    await cap();
  } else {
    final parts =
        mode == 'chunk'
            ? [
              for (var i = 0; i < doc.length; i += 3)
                doc.substring(i, i + 3 > doc.length ? doc.length : i + 3),
            ]
            : toks(doc);
    var acc = '';
    for (final tk in parts) {
      if (mode == 'chat') {
        acc += tk;
        await t.pumpWidget(host(mk(null, acc)));
      } else {
        sc.add(tk);
      }
      for (var g = 0; g < (mode == 'chunk' ? 1 : gap); g++) {
        await cap();
      }
    }
  }
  if (mode != 'chat') unawaited(sc.close());
  // Wait for the ACTUAL completion frame deterministically, rather than
  // assuming any FIXED iteration count is "long enough" in real time.
  //
  // Two things this used to get wrong (both found via round-10 verify,
  // both only reproducing under real concurrent machine load - `frame()`
  // is real-Stopwatch-paced and `snap()` does real `toImage()` work, see
  // `frame()`'s own doc, so this whole loop's real-time budget shrinks
  // relative to wall-clock delay under contention):
  //
  // 1. A `caret == true` special case force-stopped at a fixed guard>90,
  //    on the theory that a pulsing caret keeps `hasScheduledFrame` true
  //    forever. It doesn't - `_caretVisible` (and `_needsTicking`'s caret
  //    clause) turns false the instant `_isComplete` flips - but under
  //    load 90 real-paced iterations was not always enough real time for
  //    the stream to actually finish revealing first, so the loop could
  //    stop on a frame where the widget was still genuinely mid-reveal
  //    with its caret still legitimately visible.
  // 2. Even without that cap, a SINGLE instantaneous `!hasScheduledFrame`
  //    reading is not itself a safe "truly done" signal: the reveal is
  //    driven by `RevealScheduler`'s own real `Timer.periodic` (see
  //    `lib/src/engine/reveal_scheduler.dart`), entirely independent of
  //    Flutter's frame scheduling - between two of its ticks,
  //    `hasScheduledFrame` is legitimately false for a moment even though
  //    more content/fade-in is still coming once the next tick fires.
  //    Under light load that gap is short enough that the next `cap()`
  //    call reliably lands after the next tick; under heavy contention
  //    (competing processes stealing CPU from this same isolate, which is
  //    single-threaded - the very `toImage()` calls in `cap()` itself
  //    delay the scheduler's own timer from firing) that gap can outlast
  //    a single check, so the guard loop could sample its lone quiet
  //    instant and wrongly call it final - reproduced under concurrent
  //    load as a MUCH larger divergence than the caret alone (a genuinely
  //    still-settling block, not just a leftover caret glyph).
  //
  // The fix for both: require `!hasScheduledFrame` to hold continuously
  // for a minimum stretch of REAL wall-clock time - comfortably wider
  // than both the scheduler's own 30ms default tick interval and
  // `fadeInDuration`'s 300ms default - before treating the stream as
  // settled, instead of trusting one instantaneous sample.
  //
  // Measured in real elapsed time (a `Stopwatch`), NOT a fixed iteration
  // count: a first attempt at this used "N consecutive idle guard-loop
  // iterations" instead, which measurably helped but was still an
  // iteration count wearing a debounce's clothes - under genuinely severe
  // contention a single `cap()` iteration's real wall time can itself
  // exceed the whole intended debounce window, so counting iterations
  // still under-waits precisely when contention is worst (confirmed: it
  // cut this failure's rate but did not eliminate it under concurrent
  // full-suite load). Requiring a real elapsed DURATION of continuous
  // idleness is correct regardless of how long any individual iteration
  // takes. The outer wall-clock ceiling (generous - this file's own
  // `@Timeout` is 900s) stays as the safety valve against a genuinely
  // stuck ticker, replacing the old fixed `guard < 400` iteration cap for
  // the same reason.
  const requiredIdleDuration = Duration(milliseconds: 600);
  // Generous - this file's own `@Timeout` is 900s, and every call site
  // wraps a single `go()` per test - real settling under normal (even
  // moderately loaded) conditions finishes in well under a second of
  // this budget; the ceiling only matters as a backstop against a
  // genuinely stuck ticker.
  const overallCeiling = Duration(seconds: 300);
  final overall = Stopwatch()..start();
  Stopwatch? idleFor;
  while (overall.elapsed < overallCeiling) {
    await cap();
    if (t.binding.hasScheduledFrame) {
      idleFor = null;
    } else {
      idleFor ??= Stopwatch()..start();
      if (idleFor.elapsed >= requiredIdleDuration) break;
    }
  }
  final last = frames.last;
  final lastRects = rects.last;
  final r = analyse(frames, rects, last, lastRects);
  final bare = await bareSnap(t, doc, build: buildBare);
  final diff = pixDiff(last, bare);

  // ignore: avoid_print
  print(
    'INV[$name] pops=${r.pops} dips=${r.dips}/${r.words} '
    'worstDip=${r.worstDip.toStringAsFixed(2)} '
    'worstFirst=${r.worstFirst.toStringAsFixed(2)} bareDiffPx=$diff '
    'frames=${frames.length}'
    '${r.details.isEmpty ? '' : '\n   ${r.details.join('\n   ')}'}',
  );

  expect(
    r.dips,
    0,
    reason:
        'settled text dipped >0.05 in $name (worstDip=${r.worstDip}):\n'
        '${r.details.join('\n')}',
  );
  // A REAL bound - never `r.words`/`lessThanOrEqualTo(r.words)` (an
  // assertion that can never fail, which B1F1 round 7 correctly flagged as
  // unacceptable). Zero by default; [maxPopFraction] only widens it for
  // call sites that document a measured, currently-unavoidable rate - see
  // this function's own doc.
  final popCeiling = (maxPopFraction * r.words).ceil();
  expect(
    r.pops,
    lessThanOrEqualTo(popCeiling),
    reason:
        'content popped in unfaded (>=0.3 on first visible frame) in '
        '$name beyond its documented tolerance '
        '(${r.pops}/${r.words} > ${(maxPopFraction * 100).toStringAsFixed(0)}%):\n'
        '${r.details.join('\n')}',
  );
  expect(diff, '0', reason: 'final render differs from bare instant in $name');

  await t.pumpWidget(const SizedBox());
  return r;
}

/// The epoch/reset invariant case: a brand new document (a new
/// `_fadeEpoch`) replaces an in-flight stream outright - the render-tree
/// equivalent of a non-prefix `setSource`. Shared by
/// `markdown_fade_invariant_misc_test.dart` (the full `fade_matrix` case)
/// and `markdown_fade_invariant_smoke_test.dart` (the default-run smoke
/// copy) so the two never drift apart.
Future<void> epochResetCase(WidgetTester t) async {
  final sc = StreamController<String>();
  await t.pumpWidget(
    host(
      StreamingText(
        text: '',
        stream: sc.stream,
        markdownEnabled: true,
        showCursor: false,
      ),
    ),
  );
  sc.add('Alpha bravo charlie delta echo settled words here. ');
  var guard = 0;
  while (t.binding.hasScheduledFrame && guard < 400) {
    await frame(t);
    guard++;
  }
  await frame(t);
  unawaited(sc.close());

  // Sample every frame: the new doc's own words must rise monotonically to
  // their own final darkness, never pop in already dark, never dip once
  // risen.
  final words = {'Totally', 'brand', 'new', 'content', 'now'};
  await t.pumpWidget(
    host(
      const StreamingText(
        text: 'Totally brand new content now.',
        markdownEnabled: true,
        showCursor: false,
      ),
    ),
  );

  final frames = <Snap>[];
  final rects = <Map<(String, int), List<Rect>>>[];
  guard = 0;
  while (guard < 400) {
    await frame(t);
    frames.add(await snap(t));
    rects.add(occRects(t, words));
    guard++;
    if (guard > 20 && !t.binding.hasScheduledFrame) break;
  }
  final last = frames.last;
  final lastRects = rects.last;
  final r = analyse(frames, rects, last, lastRects);
  expect(
    r.dips,
    0,
    reason:
        'settled text dipped after an epoch reset:\n'
        '${r.details.join('\n')}',
  );
  expect(
    r.pops,
    0,
    reason:
        'the new document popped in unfaded after an epoch reset:\n'
        '${r.details.join('\n')}',
  );

  final bare = await bareSnap(t, 'Totally brand new content now.');
  expect(
    pixDiff(last, bare),
    '0',
    reason: 'final render differs from bare instant after epoch reset',
  );
  await t.pumpWidget(const SizedBox());
}
