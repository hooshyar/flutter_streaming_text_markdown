import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The Unicode object-replacement character `gpt_markdown`'s `TextPainter`
/// emits, once per inline `WidgetSpan`, in `text.toPlainText()` - the caret
/// is exactly one such `WidgetSpan`. Verify round 3 found the caret's own
/// placeholder can transiently appear MID-paragraph (not merely trailing
/// the very last paragraph) while a block is still being resolved (e.g. a
/// table momentarily re-rendering as a bare placeholder while its next row
/// is incomplete) - so every occurrence of this character, in every
/// paragraph, is excluded from the growth/fade-tracking text entirely (see
/// [RenderMarkdownFadeMask]'s doc). A `WidgetSpan` for other inline content
/// (an image, a link/source-tag widget) produces the same character and is
/// excluded the same way - those never get their own fade run, but the
/// real text around them still does, and nothing about excluding them ever
/// causes settled text to dip.
const int _objectReplacementChar = 0xFFFC;

/// One still-fading `[start, end)` range in the GLOBAL offset space (the
/// concatenation, in paint order, of every `RenderParagraph`'s own rendered
/// text - see [RenderMarkdownFadeMask]'s doc). Never source-text
/// coordinates.
class _GlobalRun {
  _GlobalRun(this.start, this.end, this.revealedAt);
  int start;
  int end;
  final Duration revealedAt;
}

/// A cached `(span, plainText)` pair for one `RenderParagraph`, so a
/// paragraph whose content hasn't changed since the last layout doesn't
/// pay for `toPlainText()` again.
class _ParaCache {
  _ParaCache(this.span, this.text);
  final InlineSpan span;
  final String text;
}

/// One `RenderParagraph`'s slice of the current layout's global offset
/// space: `[globalStart, globalStart + length)`.
///
/// [length] counts characters in the FADE-TRACKING text (every
/// [_objectReplacementChar] removed), not the paragraph's own raw
/// `toPlainText().length`. [indexMap] translates a fade-tracking-local
/// index back to the paragraph's own real local index; `null` means the
/// identity mapping (no placeholder characters were removed, the common
/// case).
class _Slot {
  _Slot(this.paragraph, this.globalStart, this.length, this.indexMap);
  final RenderParagraph paragraph;
  final int globalStart;
  final int length;
  final List<int>? indexMap;

  /// The paragraph's own real local offset for fade-tracking-local [i]
  /// (which may be exactly [length], one past the end).
  int toRealIndex(int i) {
    final map = indexMap;
    if (map == null) return i;
    if (i < map.length) return map[i];
    // One past the end: one past the last kept character's real index (or
    // 0 if every character in this paragraph was a placeholder).
    return map.isEmpty ? 0 : map[map.length - 1] + 1;
  }
}

/// Paints a cheap word-fade over newly-revealed markdown text, without ever
/// rebuilding or re-laying-out [child] itself.
///
/// **Why this exists (B1-S6, doc/BENCHMARKS.md "Reveal delegation
/// decision"/"B1-S5 correction"):** `gpt_markdown`'s own `animation: fade`
/// restyles its whole segment cache every tick - 2.1-2.2x time, 13x element
/// rebuilds against a 1.8x/6x budget. This widget instead finds the exact
/// on-screen box(es) of whatever text was rendered most recently and dims
/// *only those pixels*, via one full paint of [child] (same cost as bare)
/// plus a `BlendMode.dstIn` rect draw per still-fading run. It never
/// touches an `Element`, never calls `setState` on [child]'s subtree, and
/// never re-runs layout - purely a paint-time effect driven by [repaint]
/// (the same ticker that already drives the caret/plain-text fade).
///
/// **Design (round 3): one global offset space over ALL paragraphs.**
/// [performLayout] walks every `RenderParagraph` in [child]'s subtree, in
/// paint order, and concatenates each one's own rendered plain text into
/// one flat "global text" - the same shape a plain, non-markdown streaming
/// document would have if it were all one paragraph. Growth is tracked
/// against THAT concatenation, not against any single paragraph:
///
/// - **Round 1** mapped the reveal engine's own fade runs (source-text
///   coordinates) onto the rendered paragraph by distance-from-the-end;
///   wrong whenever markdown syntax made the rendered text a different
///   length than the source (a `**word**`/link/inline-code/image tail),
///   which mis-dimmed already-settled text.
/// - **Round 2** switched to tracking the LAST paragraph's own rendered
///   growth directly, resetting to empty on every paragraph-identity
///   change. Two problems: `gpt_markdown` recreates a paragraph for every
///   new list item/table cell/code line/quote (so most content popped in
///   unfaded instead of fading), AND it turns out to recreate even a
///   plain, continuously-growing top-level paragraph's `RenderParagraph`
///   object on many individual rebuilds too - so tracking "the same
///   paragraph object" is not a reliable growth signal even within a
///   single, never-block-broken paragraph. The run's range also still
///   included the caret's own trailing placeholder character, dimming the
///   caret with every word.
/// - **Round 3 (this version)** never keys anything off paragraph object
///   identity for correctness - only for a `toPlainText()` cache (skip
///   recomputing it for a paragraph whose `InlineSpan` is `identical` to
///   what was cached; a churned/replaced object just costs a
///   `toPlainText()` call, never a wrong answer). The GLOBAL concatenated
///   STRING is compared against the highest-water-mark text ever observed
///   (not merely the previous layout's - `gpt_markdown` can transiently
///   WITHHOLD already-shown content again, e.g. a table hiding its body
///   rows again for a frame while its next row is still incomplete, then
///   restoring them verbatim), three ways:
///   - if the new text is SHORTER than the peak, it's a transient
///     regression, not a rewrite - nothing changes; the content simply
///     isn't in `_slots` to paint this frame, and resumes as ordinary
///     growth once it reappears. Judged on length alone (not "and it's
///     still a literal prefix of the peak"): the filler content shown
///     during a hiccup like a table's body rows briefly disappearing isn't
///     always a clean prefix cut of what was there before, so requiring an
///     exact prefix match missed real cases of this;
///   - if the new text is at least as long AND starts with the peak, it's
///     pure growth (the overwhelmingly common case) - the delta is one new
///     run `[peakLength, newLength)`;
///   - otherwise (a genuine upstream rewrite - a `**` closing, a link
///     resolving, a list marker paragraph being replaced outright by its
///     first word instead of growing into it, or a non-append source
///     reset) every live run is CLIPPED to end at or before the point
///     where the text actually diverges, so already-settled text can never
///     dip - runs only ever exist for content still WITHIN `fadeDuration`
///     (settled ones are pruned every refresh), so nothing clipped here
///     could have already reached full opacity. The diverging tail is then
///     re-armed as a fresh run in this SAME global coordinate space - never
///     re-derived from source text or another paragraph's space - which
///     carries none of the cross-space mapping risk the first two rounds'
///     bugs came from.
///
/// A brand new paragraph (a new list item, cell, code line...) needs no
/// special case at all under this scheme: its content simply extends the
/// global text's growing tail exactly like plain prose would (or, when a
/// placeholder paragraph gets replaced outright rather than grown into,
/// falls into the rewrite branch above and still gets a fresh run) - either
/// way it fades in like real content, never popping in fully opaque.
///
/// At paint time, each run's GLOBAL `[start, end)` is mapped back onto the
/// individual paragraph(s) it actually spans via a binary search over that
/// layout's `(paragraph, globalStart)` slot list (built fresh every
/// layout, so it's never stale relative to the current tree).
///
/// **Caret exclusion.** The caret renders as exactly one `WidgetSpan`
/// (one [_objectReplacementChar] in `toPlainText()`) appended after the
/// whole document, which can only ever land in the LAST paragraph found
/// this layout. Its trailing placeholder character(s) are stripped from
/// that paragraph's contribution BEFORE it enters the global text at all,
/// so a run's end can never land on the caret's own glyph.
///
/// **Compositing.** See [paint]'s doc for why this goes through a retained
/// [ColorFilterLayer] rather than a raw `canvas.saveLayer` bracket.
///
/// **Known gap (documented, not fixed here):** if a `codeBuilder` renders
/// through a `RenderEditable` (e.g. wrapping code in a `SelectableText`)
/// rather than a `RenderParagraph`, this mask can't see or fade it at all -
/// it will simply pop in. This package's own default code rendering goes
/// through `gpt_markdown`'s built-in `Text.rich`-based renderer (a real
/// `RenderParagraph`), so the default path is unaffected; only a custom
/// `codeBuilder` that chooses `SelectableText` internally would hit this.
class MarkdownFadeMask extends SingleChildRenderObjectWidget {
  /// Creates a markdown trailing-fade mask around [child].
  const MarkdownFadeMask({
    super.key,
    required Widget super.child,
    required this.enabled,
    required this.epoch,
    required this.now,
    required this.fadeDuration,
    required this.curve,
    required this.repaint,
  });

  /// Whether the mask is active at all. `false` paints [child] unmodified,
  /// with zero extra cost and no layer pushed.
  final bool enabled;

  /// A monotonically-increasing "this is a genuinely new document" signal
  /// (see `StreamingText._fadeEpoch`'s doc). A change from the previously
  /// seen value drops every cached offset/run - never tries to diff the new
  /// text against stale state.
  final int epoch;

  /// The shared fade clock (matches the reveal engine's own).
  final Duration Function() now;

  /// How long a run takes to reach full opacity.
  final Duration fadeDuration;

  /// The easing curve applied to each run's linear progress.
  final Curve curve;

  /// Notified whenever a repaint should be attempted (e.g. every ticker
  /// frame while a fade might be in progress). Never triggers a rebuild.
  final Listenable repaint;

  @override
  RenderMarkdownFadeMask createRenderObject(BuildContext context) {
    return RenderMarkdownFadeMask(
      enabled: enabled,
      epoch: epoch,
      now: now,
      fadeDuration: fadeDuration,
      curve: curve,
      repaint: repaint,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderMarkdownFadeMask renderObject,
  ) {
    renderObject
      ..enabled = enabled
      ..epoch = epoch
      ..now = now
      ..fadeDuration = fadeDuration
      ..curve = curve
      ..repaint = repaint;
  }
}

/// An identity 5x4 color matrix: `ColorFilter.matrix` with this value is a
/// pure passthrough (every output channel equals its input channel) - see
/// [RenderMarkdownFadeMask.paint] for why a no-op filter is used anyway.
const List<double> _identityColorMatrix = <double>[
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0, //
  0, 0, 1, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// The [RenderObject] behind [MarkdownFadeMask]. See that class's doc for
/// the approach and its history.
class RenderMarkdownFadeMask extends RenderProxyBox {
  /// Creates the render object. See [MarkdownFadeMask]'s fields.
  RenderMarkdownFadeMask({
    required bool enabled,
    required int epoch,
    required this.now,
    required this.fadeDuration,
    required this.curve,
    required Listenable repaint,
  }) : _enabled = enabled,
       _epoch = epoch,
       _repaint = repaint;

  bool _enabled;

  /// Whether the mask is active. Toggling only ever triggers a repaint.
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  // `paint` conditionally pushes a `ColorFilterLayer` (only on a frame with
  // an active fade) - report compositing eligibility for the whole time
  // masking is enabled, not just on frames that actually use a layer, so
  // ancestors never see a mid-stream flip they weren't told about.
  @override
  bool get alwaysNeedsCompositing => _enabled;

  /// See [MarkdownFadeMask.now].
  Duration Function() now;

  /// See [MarkdownFadeMask.fadeDuration].
  Duration fadeDuration;

  /// See [MarkdownFadeMask.curve].
  Curve curve;

  Listenable _repaint;

  int _epoch;

  /// See [MarkdownFadeMask.epoch]. A change drops every cached offset/run
  /// immediately (not deferred to the next layout) - see the class doc.
  set epoch(int value) {
    if (_epoch == value) return;
    _epoch = value;
    _paraCache.clear();
    _slots = <_Slot>[];
    _peakGlobalText = '';
    _runs.clear();
    markNeedsPaint();
  }

  /// See [MarkdownFadeMask.repaint].
  set repaint(Listenable value) {
    if (identical(value, _repaint)) return;
    if (attached) _repaint.removeListener(markNeedsPaint);
    _repaint = value;
    if (attached) _repaint.addListener(markNeedsPaint);
  }

  /// `toPlainText()` cache, keyed by paragraph identity - a pure
  /// performance optimization (see the class doc); never load-bearing for
  /// correctness.
  final Map<RenderParagraph, _ParaCache> _paraCache =
      <RenderParagraph, _ParaCache>{};

  /// This layout's `(paragraph, globalStart, length)` slots, in paint
  /// order - rebuilt fresh every [performLayout].
  List<_Slot> _slots = <_Slot>[];

  /// The LONGEST global concatenation (in paint order, every paragraph's
  /// own rendered text, EXCLUDING the last paragraph's trailing caret
  /// placeholder(s)) ever observed, not merely last layout's. `mend()`/
  /// `gpt_markdown` can transiently WITHHOLD already-shown content again
  /// (e.g. a table hides its body rows again for a frame or two while its
  /// next row is still incomplete, before re-showing all of them at once) -
  /// comparing only against the immediately-previous layout would treat
  /// that "comes back verbatim" text as brand new growth and re-fade
  /// already-settled words. See [_refresh] for the three-way growth/
  /// temporary-regression/genuine-divergence split this enables.
  String _peakGlobalText = '';

  /// Still-fading runs, in [_peakGlobalText]'s coordinate space, oldest
  /// first.
  final List<_GlobalRun> _runs = <_GlobalRun>[];

  /// Retains the `ColorFilterLayer` [paint] pushes across frames, per the
  /// advisor directive - a fresh `ColorFilterLayer` every single frame
  /// would still be correct, but reusing one (like any composited-layer-
  /// holding `RenderObject` in the framework) avoids needlessly discarding
  /// and reallocating engine-side layer state every frame a fade is active.
  final LayerHandle<ColorFilterLayer> _layerHandle =
      LayerHandle<ColorFilterLayer>();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _repaint.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _repaint.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _layerHandle.layer = null;
    super.dispose();
  }

  @override
  void performLayout() {
    super.performLayout();
    _refresh();
  }

  /// Walks every `RenderParagraph` in [child]'s subtree (in paint order),
  /// rebuilds [_slots], and updates [_peakGlobalText]/[_runs]. Only ever run
  /// from [performLayout] - i.e. only when [child]'s actual content/shape
  /// changed - never from a ticker-only [paint] pass, so a pure fade-
  /// settling frame never re-walks the render tree.
  void _refresh() {
    final c = child;
    final found = <RenderParagraph>[];
    if (c != null) {
      void visit(RenderObject node) {
        if (node is RenderParagraph) found.add(node);
        node.visitChildren(visit);
      }

      visit(c);
    }

    if (_paraCache.isNotEmpty) {
      final keep = found.toSet();
      _paraCache.removeWhere((k, _) => !keep.contains(k));
    }

    final buffer = StringBuffer();
    final slots = <_Slot>[];
    for (var i = 0; i < found.length; i++) {
      final para = found[i];
      final span = para.text;
      final cached = _paraCache[para];
      String text;
      if (cached != null && identical(cached.span, span)) {
        text = cached.text;
      } else {
        text = span.toPlainText();
        _paraCache[para] = _ParaCache(span, text);
      }

      // Strip every object-replacement character (the caret, or any other
      // inline `WidgetSpan`) out of the fade-tracking text entirely - see
      // `_objectReplacementChar`'s doc for why this can't be limited to
      // "trailing, in the last paragraph only" the way an earlier version
      // of this file did.
      String fadeText;
      List<int>? indexMap;
      if (!text.contains(String.fromCharCode(_objectReplacementChar))) {
        fadeText = text;
        indexMap = null;
      } else {
        final sb = StringBuffer();
        final map = <int>[];
        for (var idx = 0; idx < text.length; idx++) {
          final unit = text.codeUnitAt(idx);
          if (unit == _objectReplacementChar) continue;
          sb.writeCharCode(unit);
          map.add(idx);
        }
        fadeText = sb.toString();
        indexMap = map;
      }

      slots.add(_Slot(para, buffer.length, fadeText.length, indexMap));
      buffer.write(fadeText);
    }
    _slots = slots;
    final newGlobalText = buffer.toString();

    final peak = _peakGlobalText;
    if (newGlobalText.length < peak.length) {
      // A TEMPORARY regression: the currently-rendered text is shorter
      // than the highest-water mark already reached (e.g. a table's body
      // rows briefly disappearing - sometimes replaced by unrelated filler
      // content, not simply truncated - while its next row is still
      // incomplete, then reappearing once it resolves). Deliberately not
      // limited to "and it's still a literal prefix of the peak": the
      // filler gpt_markdown shows during a transient hiccup like this
      // isn't necessarily a clean prefix cut, so checking length ALONE is
      // what actually catches it. Leave every run and `_peakGlobalText`
      // untouched either way - content not currently present simply won't
      // be found in `_slots` this frame (nothing to paint); once the real
      // content comes back it will again start with `peak` (unless it's
      // GENUINELY a shorter, different, intentionally-reset document, in
      // which case the next real growth/divergence resolves it correctly
      // anyway - see the non-prefix-reset case in the `else` branch) and
      // resume as ordinary growth from exactly where it left off, so
      // nothing already faded in gets treated as new.
    } else if (newGlobalText.startsWith(peak)) {
      // Pure growth relative to the highest-water mark ever seen - the
      // overwhelmingly common case.
      final growth = newGlobalText.length - peak.length;
      if (growth > 0) {
        _runs.add(_GlobalRun(peak.length, newGlobalText.length, now()));
      }
      _peakGlobalText = newGlobalText;
    } else {
      // A genuine reflow: `newGlobalText` is at least as long as `peak` but
      // ISN'T a plain append (a `**` closing, a link resolving, `mend()`
      // releasing a withheld tail into different content, or `gpt_markdown`
      // transiently re-rendering an entire list/table as one placeholder
      // paragraph before restoring it - verify round 4's flash bug: that
      // placeholder text is neither shorter than `peak` nor a prefix of it,
      // so naively re-arming everything past a bare common-PREFIX point
      // re-faded every already-settled list item on both the hiccup and the
      // restoration, 3-5 times each).
      //
      // First, the cheapest and most exact case: `peak` (unmodified,
      // contiguous) simply RELOCATED - something was inserted before and/or
      // after it, e.g. a lone marker/placeholder paragraph "Alpha " getting
      // prefixed by a transient "\n\n" artifact before the rest of that
      // list item streams in. Every existing run shifts by exactly how far
      // `peak` moved (still the same characters, just further along); only
      // the genuinely new edges around it get a fresh run. This is checked
      // before the prefix/suffix split below because that split requires a
      // non-empty match at BOTH ends to recognize an insertion - it can't
      // see a relocation where the common material sits at neither end of
      // `newGlobalText`.
      final peakPos = peak.isEmpty ? -1 : newGlobalText.indexOf(peak);
      if (peakPos != -1) {
        if (peakPos > 0) {
          for (final run in _runs) {
            run.start += peakPos;
            run.end += peakPos;
          }
          // The material BEFORE the relocated `peak` is deliberately never
          // armed as a fresh run, even though it's technically "new
          // characters" - it's exactly as likely to be a transient artifact
          // (stray newlines/markers gpt_markdown shows before the real
          // content of a list item resolves) as real content, and unlike
          // the material after `peak` there is no later growth check that
          // would ever re-validate it: if the artifact disappears on a
          // LATER frame (peak still frozen, so this same branch never
          // revisits it), a run created here would keep dimming whatever
          // now occupies those global positions - verified directly: this
          // is what made an unrelated, already-progressing word visibly
          // dip after a list item's leading marker artifact came and went.
        }
        // The material AFTER the relocated `peak`, in contrast, IS armed:
        // it's the tail of the document, exactly where genuinely new
        // content actually streams in, and if it turns out to have been an
        // artifact too, the next real growth step's `startsWith(peak)`
        // check (using the still-frozen, reliable `peak`) simply adds
        // another run for whatever the tail turns out to really be -
        // nothing here depends on this guess having been correct.
        final afterStart = peakPos + peak.length;
        if (newGlobalText.length > afterStart) {
          _runs.add(_GlobalRun(afterStart, newGlobalText.length, now()));
        }
        // `_peakGlobalText` deliberately NOT updated here (see the class
        // doc's "peak only ever advances on confirmed growth" invariant) -
        // `newGlobalText` may itself be a transient artifact, and adopting
        // it as the trusted baseline would make the NEXT frame's comparison
        // fail once the artifact clears, re-arming the very content this
        // branch just correctly preserved. Comparing against the same
        // reliable `peak` again next frame converges once the real
        // structure settles into a clean superset of it.
        _refreshFinish();
        return;
      }

      // Otherwise, diff on the common PREFIX *and* common SUFFIX (bounded
      // so they can't overlap within `peak`): the next most common reflow
      // shape is "something got INSERTED in the middle" of `peak` itself
      // (`peak` unchanged before and after the insertion point, only the
      // gap between is new). `unexplained` is how much of `peak` ISN'T
      // accounted for by that split.
      final prefixLen = _commonPrefixLength(peak, newGlobalText);
      final maxSuffix =
          (peak.length - prefixLen) < (newGlobalText.length - prefixLen)
              ? peak.length - prefixLen
              : newGlobalText.length - prefixLen;
      final suffixLen = _commonSuffixLength(peak, newGlobalText, maxSuffix);
      final unexplained = peak.length - prefixLen - suffixLen;

      if (unexplained <= 0) {
        // A clean insertion: `peak == newGlobalText[0:prefixLen] +
        // newGlobalText[newGlobalText.length-suffixLen:]` with a brand new
        // gap in between. Nothing in `peak` moved out of that shape, so:
        //  - a run entirely before the insertion point is untouched;
        //  - a run entirely at/after the (new) suffix start just SHIFTS
        //    forward by exactly how much the document grew - the same
        //    characters, now further along;
        //  - a run straddling the inserted gap can't be described that
        //    simply; per the "prefer no fade over a flash" directive it's
        //    dropped rather than guessed at (it was in-flight, never
        //    already-settled, so dropping it can't cause a flash - at
        //    worst a few characters stop fading early).
        final growth = newGlobalText.length - peak.length;
        final suffixStartInPeak = peak.length - suffixLen;
        for (final run in _runs) {
          if (run.end <= prefixLen) {
            continue;
          } else if (run.start >= suffixStartInPeak) {
            run.start += growth;
            run.end += growth;
          } else {
            run.end = run.start;
          }
        }
        _runs.removeWhere((r) => r.end <= r.start);

        final middleStart = prefixLen;
        final middleEnd = newGlobalText.length - suffixLen;
        if (middleEnd > middleStart) {
          _runs.add(_GlobalRun(middleStart, middleEnd, now()));
        }
      } else {
        // Neither a clean insertion nor a whole-peak relocation - `peak`
        // isn't fully (or almost fully) explained by a prefix+suffix split.
        // Every existing run past the confirmed common prefix is discarded
        // rather than guessed at: `_slots`/global offsets are rebuilt fresh
        // from the CURRENT tree every layout, so a stale run's numeric
        // range - computed against a DIFFERENT structure - could now
        // overlap anything once paragraphs have been reshuffled, including
        // content that has nothing to do with what that run originally
        // described (verified directly: leaving runs untouched here made
        // an unrelated already-fading word visibly dip, because the run's
        // old numbers landed on it purely by coincidence after a reflow).
        // A discarded IN-FLIGHT run just pops that word to full opacity a
        // little early - never a flash of already-settled text, since
        // settled text has no active run to discard in the first place.
        for (final run in _runs) {
          if (run.end > prefixLen) run.end = prefixLen;
        }
        _runs.removeWhere((r) => r.end <= r.start);

        // Arm a fresh run ONLY for whatever lies beyond both the confirmed
        // common prefix AND the previous peak's own length - i.e. content
        // that is unambiguously new (the document is longer than it has
        // ever been), not a guess about content that merely looks
        // different right now. This is what keeps a transient artifact
        // (verify round 4's list/table flash) from ever re-fading
        // already-settled text: that text sits within the old peak's
        // length, never in the "unambiguously new" range armed below.
        final armFrom = prefixLen > peak.length ? prefixLen : peak.length;
        if (newGlobalText.length > armFrom) {
          _runs.add(_GlobalRun(armFrom, newGlobalText.length, now()));
        }
      }
      // `peak` still advances even out of a reflow - once the real
      // structure resolves, comparing against the now-longer `peak` again
      // next frame is what lets a LATER, genuinely different artifact (not
      // simply the same one recurring) still be judged correctly, and
      // `_slots`/`_collectDims` only ever look at CURRENT paragraphs, so an
      // out-of-date `peak` string never leaks into what's actually painted.
      _peakGlobalText = newGlobalText;
    }

    _refreshFinish();
  }

  /// Prunes runs that can no longer be active, so a long-running stream
  /// never accumulates an unbounded backlog of settled runs. Shared by
  /// every branch of [_refresh].
  void _refreshFinish() {
    final nowValue = now();
    _runs.removeWhere((r) => nowValue - r.revealedAt >= fadeDuration);
  }

  /// Every still-fading run's rect (in THIS render object's local
  /// coordinate space) and alpha. Exposed (read-only) purely so tests can
  /// assert the fade curve directly - without screenshots - instead of
  /// only through [paint]'s side effects.
  @visibleForTesting
  List<(Rect rect, double alpha)> debugActiveDims() => _collectDims();

  List<(Rect rect, double alpha)> _collectDims() {
    if (_runs.isEmpty || _slots.isEmpty) return const [];
    final nowValue = now();
    final dims = <(Rect, double)>[];

    for (final run in _runs) {
      if (run.end <= run.start) continue;
      final elapsed = nowValue - run.revealedAt;
      if (elapsed >= fadeDuration) continue;
      final t =
          elapsed <= Duration.zero
              ? 0.0
              : (fadeDuration <= Duration.zero
                  ? 1.0
                  : elapsed.inMicroseconds / fadeDuration.inMicroseconds);
      final progress = curve.transform(t.clamp(0.0, 1.0)).clamp(0.0, 1.0);
      if (progress >= 1.0) continue;

      // Binary search for the first slot whose range could contain
      // `run.start`, then walk forward while still overlapping the run -
      // a run may straddle more than one paragraph's slot.
      var lo = 0;
      var hi = _slots.length - 1;
      var firstOverlap = _slots.length;
      while (lo <= hi) {
        final mid = (lo + hi) >> 1;
        final slot = _slots[mid];
        if (slot.globalStart + slot.length > run.start) {
          firstOverlap = mid;
          hi = mid - 1;
        } else {
          lo = mid + 1;
        }
      }

      for (var i = firstOverlap; i < _slots.length; i++) {
        final slot = _slots[i];
        if (slot.globalStart >= run.end) break;
        final localStart = (run.start - slot.globalStart).clamp(0, slot.length);
        final localEnd = (run.end - slot.globalStart).clamp(0, slot.length);
        if (localEnd <= localStart) continue;

        final para = slot.paragraph;
        if (!para.attached) continue; // defensive; see `_refresh`'s doc.

        // Translate from fade-tracking-local (placeholder characters
        // removed) back to the paragraph's own REAL local offsets before
        // asking it for boxes.
        final realStart = slot.toRealIndex(localStart);
        final realEnd = slot.toRealIndex(localEnd);
        if (realEnd <= realStart) continue;

        final boxes = para.getBoxesForSelection(
          TextSelection(baseOffset: realStart, extentOffset: realEnd),
        );
        if (boxes.isEmpty) continue;
        // `getTransformTo` already folds in any ancestor scroll offset
        // (e.g. a table cell/row scrolled horizontally) between `para` and
        // `this`.
        final transform = para.getTransformTo(this);
        final localBounds = Offset.zero & para.size;
        for (final box in boxes) {
          final rect = box.toRect().intersect(localBounds);
          if (rect.isEmpty) continue;
          dims.add((MatrixUtils.transformRect(transform, rect), progress));
        }
      }
    }
    return dims;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final c = child;
    if (c == null) return;

    if (!_enabled) {
      _layerHandle.layer = null;
      context.paintChild(c, offset);
      return;
    }

    final dims = _collectDims();
    if (dims.isEmpty) {
      // Reduced motion / fade off / nothing currently fading: paint
      // completely unmodified, with NO layer pushed at all.
      _layerHandle.layer = null;
      context.paintChild(c, offset);
      return;
    }

    // A raw `canvas.saveLayer` here (paint child, then `drawRect` with
    // `BlendMode.dstIn` on the same canvas, then restore) is invalid the
    // moment `child`'s own subtree pushes ANY layer of its own - a code
    // block's `RepaintBoundary`, a table's internal scrollable/clip, an
    // image. `PaintingContext.paintChild` calls `stopRecordingIfNeeded()`
    // before compositing such a child, which finalizes whatever Picture
    // the raw `saveLayer` call was recorded into - with the `saveLayer`
    // left unbalanced - and starts a brand new, EMPTY canvas for anything
    // painted afterwards. The subsequent `dstIn` rects would then land on
    // that empty canvas instead of over the child's actual content, so
    // they silently do nothing: exactly verify round 3's "text after a
    // table/code block renders 15-21% darker than final" overshoot (the
    // dim never applied at all).
    //
    // `context.pushLayer` with a real layer (`ColorFilterLayer`, here with
    // an identity/no-op filter) sidesteps this: everything painted while
    // it's active - `child`'s own nested layers included - shares one
    // retained engine-side layer subtree, so a `dstIn` draw issued on
    // `ctx.canvas` AFTER `paintChild` still composites against the same
    // accumulated buffer regardless of how many sub-layers `child` pushed
    // internally.
    final layer = _layerHandle.layer ?? ColorFilterLayer();
    layer.colorFilter = const ColorFilter.matrix(_identityColorMatrix);
    context.pushLayer(layer, (innerContext, innerOffset) {
      innerContext.paintChild(c, innerOffset);
      for (final (rect, progress) in dims) {
        innerContext.canvas.drawRect(
          rect.shift(innerOffset),
          Paint()
            ..color = Color.fromRGBO(0, 0, 0, progress)
            ..blendMode = BlendMode.dstIn,
        );
      }
    }, offset);
    _layerHandle.layer = layer;
  }
}

/// The length of the common prefix shared by [a] and [b].
int _commonPrefixLength(String a, String b) {
  final max = a.length < b.length ? a.length : b.length;
  var i = 0;
  while (i < max && a.codeUnitAt(i) == b.codeUnitAt(i)) {
    i++;
  }
  return i;
}

/// The length of the common suffix shared by [a] and [b], never exceeding
/// [maxLen] (the caller bounds this so a prefix match and a suffix match
/// can never overlap the same characters of the shorter string).
int _commonSuffixLength(String a, String b, int maxLen) {
  var i = 0;
  while (i < maxLen &&
      a.codeUnitAt(a.length - 1 - i) == b.codeUnitAt(b.length - 1 - i)) {
    i++;
  }
  return i;
}
