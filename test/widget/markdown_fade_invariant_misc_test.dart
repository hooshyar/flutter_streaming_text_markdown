// B1-S6 round-6 invariant probe: the `**` mid-stream closing-rewrite case,
// and an epoch/reset sequence (a brand new document replacing an in-flight
// one) sampled with the strict per-occurrence invariant harness.
@Timeout(Duration(seconds: 900))
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_streaming_text_markdown/flutter_streaming_text_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

import 'markdown_fade_invariant_lib.dart';

void main() {
  group('bold `**` mid-stream closing rewrite', () {
    const doc =
        'Alpha **bravo charlie** delta echo foxtrot **golf hotel** india. ';
    for (final caret in [false, true]) {
      for (final mode in ['stream', 'chunk']) {
        testWidgets(
          'mode=$mode caret=$caret',
          (t) => go(
            t,
            'misc.boldRewrite.$mode.caret=$caret',
            doc,
            caret: caret,
            gap: 2,
            mode: mode,
          ),
        );
      }
    }
  });

  group('epoch reset: a brand new document mid-stream', () {
    testWidgets('never dips and settles to the new doc, caret off', (t) async {
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

      // A brand new `StreamingText` (a new `_fadeEpoch`) replaces the old
      // one outright - the render-tree equivalent of a non-prefix
      // `setSource`. Sample every frame: the new doc's own words must rise
      // monotonically to their own final darkness, never pop in already
      // dark, never dip once risen.
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
    });
  });
}
