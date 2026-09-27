import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The Unicode object-replacement character `gpt_markdown`'s `TextPainter`
/// emits, once per inline `WidgetSpan`, in `text.toPlainText()` - the caret
/// is exactly one such `WidgetSpan`. Every occurrence of this character, in
/// every paragraph, is excluded from the fade-tracking text entirely (see
/// [RenderMarkdownFadeMask]'s doc): it can appear transiently mid-paragraph,
/// not merely trailing the very last one, while a block is still resolving.
const int _objectReplacementChar = 0xFFFC;

/// A cached `(span, plainText)` pair for one `RenderParagraph`, so a
/// paragraph whose content hasn't changed since the last layout doesn't
/// pay for `toPlainText()` again.
class _ParaCache {
  _ParaCache(this.span, this.text);
  final InlineSpan span;
  final String text;
}

/// One still-fading `[start, end)` range in a SLOT's own local
/// fade-tracking-text coordinate space (never a global/concatenated space,
/// and never source-text coordinates).
class _SlotRun {
  _SlotRun(this.start, this.end, this.revealedAt);
  int start;
  int end;
  final Duration revealedAt;
}

/// One slot's persisted state across layouts: the committed baseline text
/// its runs are keyed against, its still-fading runs, and the bookkeeping
/// needed for the rewrite hysteresis (adopt only once the SAME new text has
/// been seen on two consecutive layouts).
class _BaselineSlot {
  _BaselineSlot(this.text);

  /// The last text this slot was confirmed to actually contain - runs are
  /// always in THIS string's coordinate space. Only ever updated on
  /// confirmed growth or a hysteresis-confirmed rewrite adopt - never on a
  /// transient shrink or an unconfirmed rewrite candidate.
  String text;

  /// Still-fading runs against [text]'s coordinate space, oldest first.
  final List<_SlotRun> runs = <_SlotRun>[];

  /// A candidate replacement text seen on the immediately-preceding layout
  /// that was neither growth nor a transient shrink of [text] - `null` when
  /// there is no pending rewrite candidate.
  String? pendingText;

  /// How many CONSECUTIVE layouts [pendingText] has been seen unchanged.
  /// Adopted once this reaches 2.
  int pendingCount = 0;

  /// Provisional runs for [pendingText], armed the moment it's FIRST seen
  /// (not merely once adopted) via the same history-overlap de-duplication
  /// a brand new slot gets - see [RenderMarkdownFadeMask._collectDims]'s
  /// doc for why painting must consult these while a candidate is still
  /// pending, not just [runs]/[text]: [text] is deliberately left untouched
  /// during the pending window (that's the whole point of the hysteresis),
  /// but the slot's ACTUAL on-screen text already shows [pendingText] - if
  /// paint only ever validated against [text], content that shares nothing
  /// with the old (possibly artifact) [text] would render fully opaque for
  /// the entire pending window, a real, visible pop. Preserving these
  /// across repeated identical sightings (rather than re-arming with a
  /// fresh timestamp) also means the tail of a since-adopted rewrite
  /// continues the SAME fade a user may already be watching, instead of
  /// restarting it at adopt time.
  final List<_SlotRun> pendingRuns = <_SlotRun>[];
}

/// This layout's `(paragraph, length, indexMap)` for one slot - rebuilt
/// fresh every [RenderMarkdownFadeMask.performLayout].
///
/// [length] counts characters in the FADE-TRACKING text (every
/// [_objectReplacementChar] removed), not the paragraph's own raw
/// `toPlainText().length`. [indexMap] translates a fade-tracking-local
/// index back to the paragraph's own real local index; `null` means the
/// identity mapping (no placeholder characters were removed, the common
/// case).
class _PaintSlot {
  _PaintSlot(this.paragraph, this.length, this.indexMap);
  final RenderParagraph paragraph;
  final int length;
  final List<int>? indexMap;

  /// The paragraph's own real local offset for fade-tracking-local [i]
  /// (which may be exactly [length], one past the end).
  int toRealIndex(int i) {
    final map = indexMap;
    if (map == null) return i;
    if (i < map.length) return map[i];
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
/// **Design (round 5, advisor-directed): per-slot state, no global offset
/// space.**
///
/// Rounds 1-4 (see doc/BENCHMARKS.md's B1-S6 history) all tracked growth
/// against ONE flat concatenation of every `RenderParagraph`'s rendered
/// text. That collapsed under four distinct failure modes verify round 5
/// found (`scratchpad/stm/vb5/`):
///
/// - **(a) Growing list items.** A global peak plus `peak.contains(slotText)`
///   re-arms a WHOLE list item every time it grows (`'Alpha '` becoming
///   `'Alpha bravo'`), because the peak string itself keeps changing shape
///   underneath already-settled content elsewhere in the same peak.
/// - **(b) Artifact frames become the peak.** A transient render like
///   `'\n\n\n-'` gets adopted as the new peak, and later real content pops
///   because it no longer looks like growth relative to that artifact.
/// - **(c) Repeated content.** Identical text in two places (`'- Yes'`
///   three times, identical table cells) collapses under a single string
///   comparison, so one occurrence gets excluded/mis-tracked.
/// - **(d) A non-strictly-increasing epoch.** Summing a per-engine base with
///   the engine's own epoch is not monotonic across an engine swap (see
///   `StreamingText._fadeEpoch`'s doc) - a repeat value fails to clear
///   cached state at all.
///
/// The redesign tracks each `RenderParagraph`'s SLOT (its ordinal index in
/// paint order) independently, keyed by `(slot, localStart, localEnd, t0)`
/// - never a global string. This makes (a)-(c) structural non-issues: a
/// slot's own text is compared only against ITS OWN previous text, so two
/// slots with identical content never interact, and a list item's own
/// growth is tracked exactly like a single growing paragraph would be.
/// (d) is fixed on the `StreamingText` side (a real monotonic counter).
///
/// Per slot, each layout classifies the new text against the slot's
/// baseline:
///
/// - **growth** (new text starts with the old, and is longer): adopt the
///   new text as the baseline and arm `[old.length, new.length)`.
/// - **identical**: nothing changes.
/// - **transient shrink** (the old text starts with the new, shorter, one):
///   the baseline is KEPT as-is and nothing is armed - `gpt_markdown` can
///   transiently withhold already-shown content again (a table hiding its
///   body rows for a frame), and the content simply isn't painted (nothing
///   to dim) until it resumes growing from the retained baseline.
/// - **rewrite** (neither of the above): the baseline is kept until the
///   SAME new text is observed on two CONSECUTIVE layouts, then adopted -
///   this is what makes a single-frame artifact (b) or an in-flight
///   reflow harmless; only a genuinely stable replacement ever gets
///   adopted. On adopt: runs over the common prefix of old/new text are
///   kept (truncated to the prefix boundary, never extended); the
///   rewritten tail is armed as a fresh run ONLY IF the old text's region
///   beyond that prefix still had an active (unexpired) run - i.e. it
///   hadn't fully settled - otherwise the tail is left unarmed (renders
///   opaque immediately, since it's replacing already-settled content).
///   Adopting never removes or shrinks a still-active run over the shared
///   prefix, so it can never LOWER an already-visible glyph's opacity.
/// - **new slot** (beyond the current baseline count): adopted outright and
///   its whole text armed as a fresh run - a brand new list item, cell,
///   code line, or quote needs no special case, it fades in like any other
///   new content.
/// - **slot count drop**: extra baseline slots beyond the new, lower count
///   are RETAINED indefinitely (never discarded by a count change alone -
///   only an [epoch] change ever clears them). A fixed short hysteresis
///   (e.g. "two consecutive layouts") was tried first and rejected: a real
///   `gpt_markdown` table transiently collapsing to just its header while
///   its next body row is still incomplete measurably outlasts two
///   layouts (`scratchpad/stm/`'s diagnostic reproduction held a lower
///   count for four consecutive layouts before the row reappeared) - a
///   short timeout dropped the hidden rows' baseline/runs regardless, so
///   they came back as "new" slots and re-faded from scratch, exactly the
///   double-fade bug this design exists to prevent. Retaining indefinitely
///   costs nothing bounded content can't already afford (a document's
///   paragraph count is bounded, and [epoch] clears everything on a
///   genuinely new document anyway) and this is the side that can never
///   cause a visible flash: a retained-but-currently-absent slot simply
///   isn't painted (there is no current paragraph for it) until its exact
///   content reappears at the same ordinal position, at which point it is
///   the ordinary "identical"/"growth" case, not a new slot.
///
/// **Paint-time validity.** A run is only ever painted against the SLOT'S
/// CURRENT rendered text (which may differ from the run's own baseline
/// text during a transient shrink or an unconfirmed rewrite candidate): if
/// the current text doesn't contain the exact same characters the run
/// covers at the same positions, the run is dropped for this frame. A
/// dropped run may only ever make its range appear OPAQUE (paint nothing,
/// i.e. full alpha) - it can never paint alpha 0, so a mismatch can at
/// worst pop a few characters in early, never blank out settled text.
///
/// **Caret exclusion.** The caret renders as exactly one `WidgetSpan` (one
/// [_objectReplacementChar] in `toPlainText()`), stripped out of every
/// slot's fade-tracking text before any comparison happens, so a run's
/// range can never land on the caret's own glyph.
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
  /// seen value drops every cached slot/run - never tries to diff the new
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

  /// See [MarkdownFadeMask.epoch]. A change drops every cached slot/run
  /// immediately (not deferred to the next layout) - see the class doc.
  set epoch(int value) {
    if (_epoch == value) return;
    _epoch = value;
    _paraCache.clear();
    _paintSlots = <_PaintSlot>[];
    _currentTexts = <String>[];
    _baseline.clear();
    _orphanPool.clear();
    _lastCommittedPaintText.clear();
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

  /// This layout's paint-time slots, in paint order (index == slot ordinal)
  /// - rebuilt fresh every [performLayout].
  List<_PaintSlot> _paintSlots = <_PaintSlot>[];

  /// This layout's fade-tracking text per slot (index == slot ordinal) -
  /// may differ from the matching [_baseline] entry's `text` during a
  /// transient shrink or an unconfirmed rewrite candidate. Used only for
  /// paint-time run validity checks.
  List<String> _currentTexts = <String>[];

  /// Persisted per-slot state (baseline text, runs, rewrite hysteresis),
  /// indexed by slot ordinal. Can be LONGER than [_paintSlots] whenever the
  /// document currently renders fewer paragraphs than it has at its peak -
  /// see the class doc's "slot count drop" bullet for why these are never
  /// proactively discarded by a count change alone.
  final List<_BaselineSlot> _baseline = <_BaselineSlot>[];

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
  /// rebuilds [_paintSlots]/[_currentTexts], and updates [_baseline]. Only
  /// ever run from [performLayout] - i.e. only when [child]'s actual
  /// content/shape changed - never from a ticker-only [paint] pass, so a
  /// pure fade-settling frame never re-walks the render tree.
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

    final paintSlots = <_PaintSlot>[];
    final currentTexts = <String>[];
    for (final para in found) {
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
      // inline `WidgetSpan`) out of the fade-tracking text entirely.
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

      paintSlots.add(_PaintSlot(para, fadeText.length, indexMap));
      currentTexts.add(fadeText);
    }

    final n = currentTexts.length;
    final nowValue = now();

    // A lower slot count than `_baseline.length` is deliberately NEVER
    // treated as a permanent removal here - see the class doc's "slot count
    // drop" bullet. The extra baseline entries are simply left untouched
    // (not iterated below, since the loop only covers `0..n-1`); they carry
    // no per-frame cost and only ever matter again if their exact content
    // reappears at the same ordinal position.

    // Departures discovered WITHIN this single `_refresh` call (a slot's
    // baseline changing to something that isn't a growth of its old text -
    // see the PASS 1 loop below) - searched by `_overlapWithHistory` IN
    // ADDITION TO the persistent, paint-committed `_orphanPool`, and
    // discarded at the end of this method either way (never merged into
    // `_orphanPool` itself).
    //
    // This closes a real ordering race `_orphanPool` alone can't: slots are
    // processed by ordinal index, and `_orphanPool` only gains a new entry
    // once `_commitPaintedTexts` runs at the NEXT paint - so when slot 0
    // vacates `'Alpha bravo'` (adopting an artifact instead) and slot 1,
    // in this SAME pass, is trying to adopt that exact `'Alpha bravo'`
    // text apparently relocating from slot 0, `_orphanPool` alone hasn't
    // caught up yet and slot 1 would arm a fully fresh (wrong) fade for
    // content already on screen. The dependency can point EITHER way
    // between two slots in the same layout (verified directly: the
    // opposite direction - a LOWER-indexed slot needing a HIGHER-indexed
    // slot's departure - is exactly as common, e.g. slot 0 reclaiming
    // `'Alpha bravo'` from slot 1 in the same layout that slot 1 itself
    // moves on to `'Charlie '`), so a SINGLE index-order pass can't collect
    // a departure before an earlier slot needs it. `_refresh` is therefore
    // split into two passes over `0..n-1`:
    // - PASS 1 classifies every slot (growth/identical/shrink/rewrite-
    //   candidate), applies anything that doesn't need overlap info
    //   (growth, identical, shrink) immediately, and for a rewrite
    //   candidate records its departure into `frameDepartures` right away
    //   and stashes the slot's index for pass 2 - so by the time PASS 2
    //   starts, EVERY slot's departure this layout is already known,
    //   regardless of which index it came from.
    // - PASS 2 handles everything that needed overlap info (a brand new
    //   slot's arm, and a rewrite candidate's first-sighting `pendingRuns`
    //   / an already-pending candidate's adoption), now that
    //   `frameDepartures` is complete.
    //
    // Verified directly against `markdown_fade_verify4_test.dart`'s
    // bulleted/nested-list `caret=true` cases, which failed consistently
    // in isolation (not merely under full-suite timing noise) before this
    // fix, with a real one-frame dip visible in the pixel trace.
    final frameDepartures = <String>[];
    final rewriteIndices = <int>[];

    // PASS 1.
    for (var i = 0; i < n; i++) {
      if (i >= _baseline.length) continue; // a brand new slot - PASS 2.

      final bs = _baseline[i];
      final newText = currentTexts[i];
      // Prune runs that can no longer be active BEFORE diffing, so a
      // rewrite's "was the old region still fading" check below only ever
      // sees genuinely still-active runs, never a stale one that merely
      // hasn't been swept yet.
      bs.runs.removeWhere((r) => nowValue - r.revealedAt >= fadeDuration);
      bs.pendingRuns.removeWhere(
        (r) => nowValue - r.revealedAt >= fadeDuration,
      );

      final oldText = bs.text;
      if (newText == oldText) {
        bs.pendingText = null;
        bs.pendingCount = 0;
        bs.pendingRuns.clear();
        continue;
      }
      if (newText.length > oldText.length && newText.startsWith(oldText)) {
        // Pure growth - the overwhelmingly common case.
        bs.runs.add(_SlotRun(oldText.length, newText.length, nowValue));
        bs.text = newText;
        bs.pendingText = null;
        bs.pendingCount = 0;
        bs.pendingRuns.clear();
        continue;
      }
      if (newText.length < oldText.length && oldText.startsWith(newText)) {
        // Transient shrink - `gpt_markdown`/`mend()` withheld already-shown
        // content again. Keep the baseline untouched; nothing to arm since
        // the withheld content simply isn't in `currentTexts` to paint this
        // frame. Resumes as ordinary growth once it reappears.
        bs.pendingText = null;
        bs.pendingCount = 0;
        bs.pendingRuns.clear();
        continue;
      }

      // A rewrite candidate: neither growth nor a transient shrink of the
      // baseline. This slot's rendered text has, as of THIS layout,
      // genuinely departed from `oldText` (whether or not the hysteresis
      // ever adopts a stable replacement) - record that immediately so
      // EVERY slot in PASS 2 (regardless of index) can see it.
      if (oldText.isNotEmpty) frameDepartures.add(oldText);

      if (bs.pendingText == newText) {
        bs.pendingCount += 1;
      } else {
        bs.pendingText = newText;
        bs.pendingCount = 1;
        bs.pendingRuns.clear();
      }
      rewriteIndices.add(i);
    }

    // PASS 2 - `frameDepartures` is now complete for this layout.
    for (var i = 0; i < n; i++) {
      if (i < _baseline.length) continue;
      final newText = currentTexts[i];
      // A brand new slot (a new list item, cell, code line, quote...).
      //
      // Real `gpt_markdown` streaming can insert a transient artifact
      // paragraph BEFORE genuinely continuing content, which momentarily
      // shoves that content's ordinal index forward WHILE it also grows
      // (e.g. slot 0 was growing `'Alpha '`; the next layout transiently
      // renders an artifact at slot 0 and the grown `'Alpha bravo'` at a
      // brand new slot 1, before slot 0 reclaims `'Alpha bravo'` on a
      // LATER layout once the artifact clears) - verify round 5's
      // diagnostic reproduction (`scratchpad/stm/`) confirmed this exact
      // shape for list items with a caret. Treating slot 1 as
      // unconditionally, fully brand new would re-arm `'Alpha'` from
      // scratch even though it was already on screen.
      //
      // An earlier version of this fix tried to INHERIT slot 0's actual
      // runs into the new slot outright (treating it as a confirmed
      // relocation) - rejected once tested against this exact case: the
      // "relocation" often turns out to be a transient DUPLICATE, not a
      // real move (slot 0 itself reclaims the same text on the very next
      // layout via ordinary growth), leaving TWO independent baseline
      // entries tracking the same content under different indices. The
      // newer entry then goes stale the moment slot 0 wins the content
      // back, and the next genuinely different content landing at that
      // stale index reads as a mismatched, invalid run - which paints
      // OPAQUE (a pop), not merely a dip.
      //
      // The safe fix that carries none of that duplicate-state risk: scan
      // EVERY text this mask has ever confirmed committed (any slot, at
      // any point in this document's history - not just the CURRENT
      // baseline, which real `gpt_markdown` streaming can transiently
      // clear from every slot at once mid-shuffle, e.g. while a THIRD
      // list item's own artifact briefly displaces `'Alpha bravo'`
      // entirely, out of every slot simultaneously) for the LONGEST
      // committed text that is a prefix of this new slot's text. That
      // much of the new text has unambiguously already been shown before
      // - leave it unarmed (paints opaque immediately, never a fresh
      // low-alpha restart), and only arm the genuinely new suffix beyond
      // it.
      final overlap = _overlapWithHistory(
        newText,
        frameDepartures,
        i > 0 ? _baseline[i - 1].text : null,
      );
      final bs = _BaselineSlot(newText);
      if (newText.length > overlap) {
        bs.runs.add(_SlotRun(overlap, newText.length, nowValue));
      }
      _baseline.add(bs);
    }

    for (final i in rewriteIndices) {
      final bs = _baseline[i];
      final newText = currentTexts[i];
      // Only ADOPTED (see [_adoptRewrite]) once the SAME candidate has been
      // observed on two CONSECUTIVE layouts - a single-frame artifact never
      // survives long enough to be adopted at all. Provisional runs are
      // armed the moment the candidate is FIRST seen (via
      // [_overlapWithHistory], exactly like a brand new slot) so paint has
      // something better than "everything is invalid, snap opaque" to show
      // for the whole pending window - see [_BaselineSlot.pendingRuns]'s
      // doc. `bs.pendingCount == 1` here means PASS 1 just set this
      // candidate for the first time this call.
      if (bs.pendingCount == 1) {
        final overlap = _overlapWithHistory(
          newText,
          frameDepartures,
          i > 0 ? _baseline[i - 1].text : null,
        );
        if (newText.length > overlap) {
          bs.pendingRuns.add(_SlotRun(overlap, newText.length, nowValue));
        }
      }
      if (bs.pendingCount >= 2) {
        _adoptRewrite(bs, newText);
      }
    }

    _paintSlots = paintSlots;
    _currentTexts = currentTexts;
  }

  /// Adopts [newText] as slot [bs]'s new baseline, having been confirmed
  /// stable for two consecutive layouts. Keeps every run over the common
  /// prefix (truncated, never extended - so this can never LOWER an
  /// already-visible glyph's opacity), and promotes
  /// [_BaselineSlot.pendingRuns] - armed when the candidate was FIRST seen,
  /// via [_overlapWithHistory] at that time (see that field's doc) - into
  /// [_BaselineSlot.runs], preserving their original `revealedAt` so the
  /// tail continues whatever fade a user may already have been watching
  /// during the pending window instead of restarting it here.
  ///
  /// An earlier version of this gated the whole tail on whether [bs]'s OWN
  /// run list still had anything active beyond the common prefix
  /// (`wasTailFading`) - as a proxy for "is this replacing settled content,
  /// in which case don't fade the replacement either". Rejected once
  /// tested: [bs]'s own runs can be empty for reasons that have NOTHING to
  /// do with whether the NEW text was ever shown before - e.g. this exact
  /// slot's PREVIOUS content was itself de-duplicated against history a
  /// moment ago (so it has no runs of its own), even though the text now
  /// replacing it (e.g. the next list item's real content) has never been
  /// on screen. Gating on the old slot's own fading state made that
  /// genuinely brand new content pop in fully opaque. [pendingRuns] is the
  /// right signal instead: it was computed from [newText] itself against
  /// the FULL history, so it already says "already shown" or "never shown"
  /// correctly regardless of what [bs] itself was doing before.
  void _adoptRewrite(_BaselineSlot bs, String newText) {
    final oldText = bs.text;
    final prefixLen = _commonPrefixLength(oldText, newText);

    for (final run in bs.runs) {
      if (run.end > prefixLen) run.end = prefixLen;
    }
    bs.runs.removeWhere((r) => r.end <= r.start);

    for (final r in bs.pendingRuns) {
      final start = r.start < prefixLen ? prefixLen : r.start;
      if (r.end > start) {
        bs.runs.add(_SlotRun(start, r.end, r.revealedAt));
      }
    }
    bs.pendingRuns.clear();

    bs.text = newText;
    bs.pendingText = null;
    bs.pendingCount = 0;
  }

  /// Every text this mask has ever actually PAINTED for some slot (see
  /// [_commitPaintedTexts]) since the last [epoch] change - see
  /// [_overlapWithHistory]. Deliberately populated at PAINT time, never at
  /// [_refresh] (layout) time: `gpt_markdown` can run several internal
  /// rebuild/relayout passes within a single frame, so a slot's content at
  /// one [_refresh] call can be superseded by another [_refresh] call
  /// before Flutter ever actually paints a frame - recording eagerly at
  /// layout time was tried first and rejected because it let a transient,
  /// NEVER-ONSCREEN duplicate (e.g. a list item's real content momentarily
  /// also appearing, one frame early, under a brand new slot before its
  /// real home reclaims it) poison a LATER, genuinely first-ever paint of
  /// different content that happened to share a prefix, marking it opaque
  /// despite a user never having seen it. Recording only what
  /// [_collectDims] (called from [paint]) actually consumed guarantees
  /// every entry here was truly, at some point, on screen.
  ///
  /// This is a POOL OF ORPHANS, not a full paint history - it holds a text
  /// exactly when some slot stopped displaying it for a reason OTHER than
  /// growing past it (see [_commitPaintedTexts]), and each entry is
  /// CONSUMED (removed) the moment [_overlapWithHistory] uses it. A plain
  /// "was this text ever painted" record (an earlier version of this) was
  /// rejected on two counts:
  /// - it can't tell apart a slot's own natural GROWTH (`'Run'` ->
  ///   `'Run the'` -> `'Run the tests'`) from a genuine departure - every
  ///   intermediate growth stage got recorded too, so a LATER, genuinely
  ///   different second `"Run the tests"` list item found a false "already
  ///   shown" match against the FIRST item's own now-superseded growth
  ///   stages and popped in opaque despite never having been on screen;
  /// - a persistent (non-consuming) "committed more times than currently
  ///   claimed" count was tried next and still double-counted: once a
  ///   spare was found for one relocation, the same historical entry could
  ///   still show as "spare" for a SECOND, unrelated event later, because
  ///   nothing ever reduced the count back down when it got used.
  final List<String> _orphanPool = <String>[];

  /// The most entries [_orphanPool] is allowed to hold before the oldest
  /// are dropped - a generous bound so an effectively-unbounded stream
  /// can't grow this list without limit; ordinary documents (a bounded
  /// number of paragraphs, each orphaned at most a handful of times) never
  /// come close to it.
  static const int _maxOrphanPool = 2048;

  /// The last text actually painted for each slot ordinal (parallel to
  /// [_baseline]/[_paintSlots]) - lets [_commitPaintedTexts] tell a genuine
  /// transition (worth possibly orphaning the old value) apart from an
  /// unchanged repaint.
  final List<String> _lastCommittedPaintText = <String>[];

  /// Detects every slot whose rendered text genuinely changed since the
  /// last real paint and, when that change was NOT simple growth (the old
  /// text is not a prefix of the new one - i.e. the old text is nowhere
  /// left for this slot to have grown out of), adds the OLD text to
  /// [_orphanPool] as a candidate for [_overlapWithHistory] to match
  /// elsewhere. Called once per real [paint] (both the enabled-with-
  /// active-dims path and the nothing-to-dim path; either way the content
  /// is truly on screen this frame) - see [_orphanPool]'s doc for why this
  /// must be paint-time, not layout-time.
  void _commitPaintedTexts() {
    final n =
        _paintSlots.length < _currentTexts.length
            ? _paintSlots.length
            : _currentTexts.length;
    while (_lastCommittedPaintText.length < n) {
      _lastCommittedPaintText.add('');
    }
    for (var i = 0; i < n; i++) {
      final t = _currentTexts[i];
      final old = _lastCommittedPaintText[i];
      if (t != old) {
        if (old.isNotEmpty && !t.startsWith(old)) {
          _orphanPool.add(old);
          if (_orphanPool.length > _maxOrphanPool) {
            _orphanPool.removeAt(0);
          }
        }
        _lastCommittedPaintText[i] = t;
      }
    }
  }

  /// The length of the longest prefix of [text] that matches (and CONSUMES,
  /// removing it) an entry in [_orphanPool] OR [frameDepartures] - i.e. text
  /// some OTHER slot used to display and has since genuinely stopped
  /// displaying (not merely grown past). That's unambiguously the same
  /// content having moved to a different slot (`gpt_markdown`'s own
  /// transient paragraph churn - see the class doc), so it's safe to treat
  /// as already-shown here too. Consuming the match (rather than leaving it
  /// in the pool) means a SECOND, later, genuinely-different occurrence of
  /// the same text - `'- Yes'` three times, identical table cells - can't
  /// also match the same one-time orphan; it finds the pool empty for that
  /// text and properly fades on its own.
  ///
  /// [frameDepartures] (this SAME `_refresh` call's own local list, never
  /// [_orphanPool] itself) is searched too, and takes priority when both
  /// pools contain a match of equal length - it reflects a departure that
  /// just happened moments ago, in a slot processed earlier in this exact
  /// pass, which is the freshest possible evidence.
  int _overlapWithHistory(
    String text,
    List<String> frameDepartures,
    String? adjacentLiveText,
  ) {
    // A LIVE check first, never consumed: if the IMMEDIATELY PRECEDING
    // slot's CURRENT baseline text shares a common prefix with `text`,
    // that much content is genuinely on screen RIGHT NOW at that other
    // slot - "new text at slot i shares a prefix with slot i-1, which
    // hasn't departed at all yet" is a real, common shape (a nested list's
    // parent item still growing at its own slot while `gpt_markdown`
    // transiently also renders its already-shown prefix under a brand new
    // slot immediately after it) - ONLY a live read, so nothing is
    // removed; the other slot keeps its own independent tracking
    // untouched.
    //
    // Deliberately scoped to ONLY the immediately preceding slot, not every
    // live baseline entry: checking against the WHOLE baseline was tried
    // first and rejected - it also matched genuinely repeated but UNRELATED
    // content (bug (c): a SECOND, later `'- Yes'`/`'- Run the tests'` list
    // item legitimately shares full text with an EARLIER one that is very
    // much still live and NOT departing, and both must fade independently).
    //
    // Also requires `text` to be a STRICT, shorter prefix of
    // `adjacentLiveText` (never an exact-length match) - even scoped to
    // just the adjacent slot, an identical ADJACENT table cell (`'| Yes |
    // Yes |'` - two distinct cells, genuinely equal length, genuinely
    // side by side) would otherwise match too. A transient duplicate from
    // `gpt_markdown`'s own paragraph churn is always a snapshot of the
    // source paragraph MID-GROWTH - strictly shorter, by construction,
    // never equal length - which is exactly what distinguishes it from two
    // independent, equal-length, coincidentally-identical cells.
    var bestLength = 0;
    if (adjacentLiveText != null && adjacentLiveText.length > text.length) {
      final cp = _commonPrefixLength(adjacentLiveText, text);
      if (cp == text.length) bestLength = cp;
    }
    // `>` (strict) from here on: a tie with the live check above is left
    // as a free, non-consuming live match rather than needlessly consuming
    // an orphan/departure entry that could still be useful for something
    // else this same layout.
    var bestInFrame = false;
    var bestIndex = -1;
    for (var i = 0; i < _orphanPool.length; i++) {
      final t = _orphanPool[i];
      if (t.length > bestLength && text.startsWith(t)) {
        bestLength = t.length;
        bestIndex = i;
        bestInFrame = false;
      }
    }
    for (var i = 0; i < frameDepartures.length; i++) {
      final t = frameDepartures[i];
      if (t.length > bestLength && text.startsWith(t)) {
        bestLength = t.length;
        bestIndex = i;
        bestInFrame = true;
      }
    }
    if (bestIndex == -1) return bestLength;
    if (bestInFrame) {
      frameDepartures.removeAt(bestIndex);
    } else {
      _orphanPool.removeAt(bestIndex);
    }
    return bestLength;
  }

  /// Every still-fading run's rect (in THIS render object's local
  /// coordinate space) and alpha. Exposed (read-only) purely so tests can
  /// assert the fade curve directly - without screenshots - instead of
  /// only through [paint]'s side effects.
  @visibleForTesting
  List<(Rect rect, double alpha)> debugActiveDims() => _collectDims();

  List<(Rect rect, double alpha)> _collectDims() {
    if (_paintSlots.isEmpty || _baseline.isEmpty) return const [];
    final nowValue = now();
    final dims = <(Rect, double)>[];

    final n =
        _paintSlots.length < _baseline.length
            ? _paintSlots.length
            : _baseline.length;
    for (var i = 0; i < n; i++) {
      final bs = _baseline[i];
      final slot = _paintSlots[i];
      final currentText = _currentTexts[i];

      // While a rewrite candidate is pending (`bs.text` deliberately still
      // holds the OLD, possibly-artifact text - see `_BaselineSlot.
      // pendingRuns`'s doc), the slot's CURRENT text already matches
      // `pendingText`, not `bs.text` - use the matching (text, runs) pair,
      // never `bs.text`/`bs.runs` against a `currentText` they were never
      // computed against.
      final String baselineText;
      final List<_SlotRun> runs;
      if (bs.pendingText != null && currentText == bs.pendingText) {
        baselineText = bs.pendingText!;
        runs = bs.pendingRuns;
      } else {
        baselineText = bs.text;
        runs = bs.runs;
      }
      if (runs.isEmpty) continue;

      for (final run in runs) {
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

        // Paint-time validity: the run only ever describes `baselineText`'s
        // coordinate space. If the slot's CURRENT text doesn't contain the
        // exact same characters at the exact same positions the run covers,
        // drop it entirely for this frame - painting nothing snaps that
        // range to fully opaque, never to alpha 0.
        if (!_runValid(baselineText, currentText, run.start, run.end)) {
          continue;
        }

        final para = slot.paragraph;
        if (!para.attached) continue; // defensive; see `_refresh`'s doc.

        final realStart = slot.toRealIndex(run.start);
        final realEnd = slot.toRealIndex(run.end);
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

    // Every real paint means every current slot's text is genuinely on
    // screen this frame - record that before anything else so
    // `_orphanPool` only ever reflects content a user could actually
    // have seen. See its doc for why this can't happen at layout time.
    _commitPaintedTexts();

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
    // they silently do nothing.
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

/// Whether [current] contains the exact same characters [baseline] has in
/// `[start, end)` at that same range - the paint-time validity check that
/// lets a run be dropped (never lowered to alpha 0) the moment the slot's
/// actually-rendered text no longer matches what the run was computed
/// against.
bool _runValid(String baseline, String current, int start, int end) {
  if (end > baseline.length || current.length < end) return false;
  for (var i = start; i < end; i++) {
    if (current.codeUnitAt(i) != baseline.codeUnitAt(i)) return false;
  }
  return true;
}
