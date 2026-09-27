import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The Unicode object-replacement character `gpt_markdown`'s `TextPainter`
/// emits, once per inline `WidgetSpan`, in `text.toPlainText()` - the caret
/// is exactly one such `WidgetSpan`. Every occurrence of this character, in
/// every paragraph, is excluded from the fade-tracking text entirely (see
/// [RenderMarkdownFadeMask]'s doc): it can appear transiently mid-paragraph,
/// not merely trailing the very last one, while a block is still resolving.
const int _objectReplacementChar = 0xFFFC;

/// Matches any Latin letter. Used to decide whether a paragraph's fade-
/// tracking text carries any visible WORD content at all - see
/// [RenderMarkdownFadeMask._refresh]'s "whitespace/marker-only paragraphs
/// are never their own slot" doc.
final RegExp _hasLetter = RegExp('[A-Za-z]');

/// ASCII/Unicode whitespace code units treated as trimmable trailing
/// fade-tracking-text noise - see [_growthPrefixLength].
bool _isFadeSpace(int codeUnit) =>
    codeUnit == 0x20 ||
    codeUnit == 0x09 ||
    codeUnit == 0x0A ||
    codeUnit == 0x0D;

/// Inline-markdown marker characters the caught-up widget can render RAW
/// (visible in the fade-tracking text) before a still-streaming close makes
/// `gpt_markdown` re-render the span styled - see [_growthPrefixLength].
/// Code units for `*`, `_`, `` ` ``, `~`, `[`.
const Set<int> _inlineMarkerCodeUnits = {0x2A, 0x5F, 0x60, 0x7E, 0x5B};

/// When `oldText` itself is not a literal prefix of `newText` (round-6
/// verify evidence, B1F1 round 7): tries a small, fixed set of
/// STRUCTURALLY-MOTIVATED trims of `oldText`'s own trailing edge - never an
/// arbitrary position - to see whether the remainder genuinely is a prefix
/// of `newText`. Two real `gpt_markdown` shapes need this:
///
/// - **A heading's trailing divider-placeholder whitespace.** `gpt_markdown`
///   renders `# Title` as `'Title\n'` plus a divider rendered as its own
///   inline placeholder - once [_objectReplacementChar] is stripped from
///   the fade-tracking text, that placeholder's presence/absence can shift
///   trailing whitespace in a way that breaks a literal prefix match even
///   though the heading's own words never changed. Trimming trailing
///   whitespace from `oldText` before checking fixes this - H2/H3 never
///   exhibit it (no divider), so they're untouched by this trim ever
///   applying (the untrimmed check in case 2 above already covers them).
/// - **An unresolved inline-markup marker.** The caught-up widget can
///   render markup RAW (`'**bold'`, visible asterisks and all) while a
///   `**`/`*`/`_`/`` ` ``/`[`/`~~` span is still open; once its close
///   streams in, `gpt_markdown` re-renders the same span styled (the
///   asterisks gone), which is a genuine, if small, rewrite rather than a
///   literal prefix extension. Trimming `oldText` back to the START of its
///   LAST occurrence of any of these marker characters - trying the
///   rightmost (least-discarding) candidate first - catches this.
///
/// Both trims are tried against `oldText`'s OWN text only - this is still
/// purely per-slot, zero cross-slot content matching. Returns the trimmed
/// length to treat as "already shown" (case 2b arms only the genuinely new
/// suffix beyond it) or `null` if neither trim makes the remainder a prefix
/// of `newText` (a genuine rewrite - falls through to case 4 unchanged).
///
/// [settledLength] guards the MARKER trim only (never the whitespace trim -
/// see below) against a real regression found in this design's own
/// testing: an early draft scanned every marker character back to the
/// START of `oldText`, and for a paragraph with an EARLIER, already-fully-
/// settled `**bold span**`, `newText.startsWith(oldText.substring(0, i))`
/// can trivially succeed at that much-earlier marker position too (a
/// document's own already-typed beginning obviously never changes) - which
/// then truncated/discarded the run covering everything after it,
/// including long-settled words, and re-armed them from elapsed-zero (a
/// real, visible dip - the opposite of this fix's entire purpose). Never
/// considering a MARKER trim point BELOW [settledLength] - text this
/// slot's own sweep has already confirmed fully faded - makes that
/// structurally impossible: only the still-unsettled TAIL of `oldText` is
/// ever eligible for a marker trim.
///
/// The whitespace trim is NEVER subject to this floor: whitespace has no
/// glyph to dim in the first place, so discarding it can never itself
/// cause a visible dip, regardless of whether it happens to already be
/// counted as "settled" (a trailing newline can settle together with the
/// word before it well before the NEXT real word streams in). The call
/// site's own `start = max(trimmed, settledLength)` still protects any
/// VISIBLE character regardless - this only affects whether the (always-
/// safe) whitespace-boundary MATCH is accepted at all.
///
/// The returned `preserveTiming` flag tells the caller which of the two
/// shapes matched: `false` for the whitespace trim (the suffix beyond it is
/// genuinely brand new - arm it fresh, from `nowValue`, exactly like
/// ordinary growth) and `true` for the marker trim (the suffix beyond it
/// can include text that was ALREADY visibly mid-fade under its raw-markup
/// form - the caller must continue that same timeline, never restart it at
/// `nowValue`, or it would visibly DIP a word back down after it had
/// already partially appeared).
(int trimmedLength, bool preserveTiming)? _growthPrefixLength(
  String oldText,
  String newText,
  int settledLength,
) {
  var trimmed = oldText.length;
  while (trimmed > 0 && _isFadeSpace(oldText.codeUnitAt(trimmed - 1))) {
    trimmed--;
  }
  if (trimmed < oldText.length &&
      newText.length > trimmed &&
      newText.startsWith(oldText.substring(0, trimmed))) {
    return (trimmed, false);
  }

  for (var i = oldText.length - 1; i >= settledLength && i >= 1; i--) {
    if (!_inlineMarkerCodeUnits.contains(oldText.codeUnitAt(i))) continue;
    if (newText.length > i && newText.startsWith(oldText.substring(0, i))) {
      return (i, true);
    }
  }
  return null;
}

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
/// and never source-text coordinates). Always expressed against that slot's
/// CURRENT [_BaselineSlot.text] - a run is never carried across a text
/// replacement that isn't simple growth (see [_BaselineSlot] doc).
class _SlotRun {
  _SlotRun(this.start, this.end, this.revealedAt);
  final int start;
  // Mutable ONLY to be truncated DOWNWARD when the trailing text it once
  // described is discarded by a trimmed-prefix growth match (case 2b) -
  // see [_growthPrefixLength]. Never extended, and never used to lower an
  // already-computed alpha.
  int end;
  final Duration revealedAt;
}

/// One slot's persisted state across layouts: the committed baseline text
/// its runs are keyed against, its still-fading runs, the "anything else"
/// (case 4) rewrite hysteresis, and the hard settled-length floor.
class _BaselineSlot {
  _BaselineSlot(this.text);

  /// The last text this slot was confirmed to actually contain - runs are
  /// always in THIS string's coordinate space. Only ever updated on growth
  /// or a hysteresis-confirmed case-4 adopt (which always adopts WITHOUT a
  /// run - see the class doc) - never on a transient one-off change.
  String text;

  /// Still-fading runs against [text]'s coordinate space, oldest first.
  final List<_SlotRun> runs = <_SlotRun>[];

  /// How many characters of [text], from the start, are permanently
  /// settled (their run has finished, or they were adopted opaque). Never
  /// decreases. See [RenderMarkdownFadeMask]'s "hard invariant" doc: no run
  /// is ever allowed to start below this floor, which makes "settled text
  /// re-dims" structurally impossible regardless of what the classifier
  /// above it computes.
  int settledLength = 0;

  /// A candidate replacement text seen on the immediately-preceding layout
  /// that was neither identical nor growth of [text] - `null` when there is
  /// no pending case-4 candidate.
  String? pendingText;

  /// How many CONSECUTIVE layouts [pendingText] has been seen unchanged.
  /// Adopted (opaque, no run - see the class doc's case 4) once this
  /// reaches 2.
  int pendingCount = 0;
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
/// **Design (round 6, "block-level simplification"): conservative,
/// tail-biased, per-slot classification. No orphan pool, no cross-slot
/// content matching, no partial-rewrite runs.**
///
/// Rounds 1-5 (see doc/BENCHMARKS.md's B1-S6 history) chased increasingly
/// clever heuristics - a global concatenated peak, then per-slot state with
/// an orphan pool of departed text, an adjacent-slot "live" check, and
/// partial-rewrite run adoption - to recognize `gpt_markdown`'s transient
/// paragraph churn (content briefly relocating slots, artifacts, etc.) as
/// "already shown" so it wouldn't re-fade. Round 6's evidence
/// (`scratchpad/stm/vb6/`) showed all of that cleverness was itself the
/// bug:
///
/// - A pending-rewrite candidate could still be assigned a RUN (an
///   "adjacent-live" or orphan-pool match), and that run's real-index span,
///   converted from fade-tracking coordinates, could land across a
///   WidgetSpan placeholder boundary - dimming the nested content the
///   placeholder stands for, taking already-settled items from 1.0 to 0.
/// - The orphan pool, matched but never fully drained in practice, and the
///   adjacent-live check reading a stale pending baseline, let REPEATED or
///   PREFIX content falsely match unrelated history and pop in fully
///   opaque with no fade at all - the exact opposite failure.
///
/// The fix the lead chose is to delete all of that cleverness rather than
/// patch it further: this design does zero cross-slot/history matching.
/// Each slot is classified ONLY against its own immediately-preceding
/// baseline text, with exactly four outcomes:
///
/// 1. **New slot appended at the tail.** `i >= baseline.length` this
///    layout, AND every earlier slot (`0..baseline.length-1`) classified
///    as identical or growth on this SAME layout (see case 2/3) - i.e. this
///    is an ordinary tail append during normal streaming, not a reshuffle.
///    Adopted outright and armed as ONE run over its whole text - the
///    "block fade". If any earlier slot is case 4 this layout, the append
///    is deferred: this ordinal index is simply left out of [_baseline] -
///    it is STILL PAINTED every frame (nothing in `_baseline` backs it, so
///    [_collectDims] has no run to apply and `gpt_markdown` paints it
///    exactly as it always does, fully opaque - not literally "un-painted")
///    - until a later layout where every earlier slot is clean, at which
///    point it's finally added. [_pendingExposedLength] tracks how much of
///    it was already visible, unmasked, during that deferred window, so
///    the eventual append only arms a run over the genuinely new suffix
///    beyond what a user already saw - never re-dimming a prefix that was
///    already fully opaque on screen.
/// 2. **Growth.** The new text starts with the old, and is longer. The old
///    baseline is extended and a run is armed over exactly the new suffix,
///    clamped to never start below the slot's [_BaselineSlot.settledLength]
///    (the hard invariant - see below).
/// 3. **Identical.** Nothing changes.
/// 4. **Anything else** - a shrink, a genuine rewrite, a non-tail
///    insertion, or any other shape that isn't 1-3. NOTHING is armed and
///    no other slot's runs are touched. The old baseline is kept as-is
///    until the SAME new text has been seen on two CONSECUTIVE layouts, at
///    which point it is adopted with **no run at all** - it renders at
///    whatever opacity `gpt_markdown` itself painted it at (i.e. fully
///    opaque; a real, deliberate pop, and the ONLY case in this design that
///    can ever pop non-tail content). A slot-COUNT drop (fewer paragraphs
///    this layout than the current baseline holds) is never truncated by
///    the drop alone, regardless of how long it persists - only an
///    [epoch] change ever clears those entries; until then they are simply
///    left untouched (not painted, since there is no current paragraph for
///    them - see [_refresh], including its "deliberate deviation" note on
///    why a short fixed hysteresis was tried and rejected here).
///
/// **Letter-less paragraphs (whitespace/marker debris) are never their own
/// slot.** `gpt_markdown` can transiently render a paragraph containing NO
/// letter at all - pure whitespace (`'\n\n'`), or bare marker/punctuation
/// debris (`'-'`, `'\n\n-'`, a lone digit, `'>'`) - BETWEEN two real blocks
/// while a document streams past a block boundary (an intro paragraph
/// followed by a list, a list marker appearing one frame before its item's
/// own text does, a paragraph followed by a table). This is a genuine
/// internal rendering artifact of `gpt_markdown` itself, not something
/// `mend()` could withhold (it never reaches `gpt_markdown` as its own
/// dangling source line - see round 5's "artifact frames become the peak"
/// history in doc/BENCHMARKS.md for the same underlying gpt_markdown
/// behavior surfacing against an earlier design). Under pure per-ordinal-
/// slot tracking (this design has NO cross-slot matching to absorb it
/// otherwise), that artifact's appearance and disappearance shifts every
/// REAL slot after it by one ordinal position for exactly as long as it's
/// visible - which [_refresh]'s case-4 hysteresis on the artifact's own
/// slot combined with case 1's tail-append rule would otherwise let slip
/// through: by the time the artifact settles into being treated as
/// "identical" (i.e. is no longer blocking `allEarlierOk`), the real
/// content that moved to a new ordinal position looks exactly like brand
/// new tail content and gets a full fresh fade, dipping already-settled
/// text back toward zero. Since a letter-less paragraph never has a visible
/// WORD to paint regardless of how it's classified (this package's fade
/// only ever targets prose; a stray digit or marker rendering at full
/// opacity immediately is not a regression this mask exists to prevent),
/// [_refresh] simply never indexes one as a slot at all - every REAL slot's
/// ordinal position is then stable across the artifact's entire transient
/// lifetime. This is what the strict per-word-occurrence invariant probes
/// (`test/widget/markdown_fade_invariant_*_test.dart`) exist to catch a
/// regression of. This is a per-paragraph FILTER, not cross-slot content
/// matching: it never looks at what any OTHER slot contains, never keeps
/// history, and changes nothing about what is ever painted (a letter-less
/// paragraph is never dimmed either way, filtered or not).
///
/// **Hard invariant: settled length.** Each slot tracks
/// [_BaselineSlot.settledLength] - the count of leading characters whose
/// run has already finished (or that were adopted opaque via case 4). A
/// newly armed run's start is always clamped to at least this value, so
/// even a classifier mistake can only ever fail to fade something (pop it
/// in opaque) - it can structurally never re-dim settled text back down.
///
/// **Runs never cover placeholder characters.** A run's `[start, end)` is
/// always in fade-tracking coordinates (every [_objectReplacementChar]
/// already stripped out). Converting that range to the paragraph's own
/// real coordinates for `getBoxesForSelection` never assumes it stays
/// contiguous: [RenderMarkdownFadeMask._realRanges] splits at every point
/// where a placeholder was removed, so a single run can produce several
/// disjoint real ranges, each ending exactly before / resuming exactly
/// after a placeholder - the placeholder's own real index is never
/// included in any range, which is exactly what stops a run from ever
/// dimming a nested `WidgetSpan`'s own children.
///
/// **Paint-time validity.** A run is only ever painted while the slot's
/// CURRENT rendered text still starts with the exact text the run was
/// created against (`bs.text`, since case 2/3 only ever extend it and case
/// 4 always replaces both text AND runs together atomically - a run and
/// its slot's `text` are always the same coordinate space by construction,
/// this check exists purely as a defensive belt for a paint call landing
/// between an in-progress `gpt_markdown` rebuild and the next `_refresh`).
/// If it doesn't, the run is dropped for this frame - painting nothing
/// snaps that range to fully opaque, it can never paint alpha 0.
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
    _pendingExposedLength.clear();
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
  /// used only for the paint-time run-validity check.
  List<String> _currentTexts = <String>[];

  /// Persisted per-slot state (baseline text, runs, case-4 hysteresis,
  /// settled length), indexed by slot ordinal. Can be LONGER than
  /// [_paintSlots] whenever the document currently renders fewer
  /// paragraphs than it has at its peak - see [_refresh]'s "slot count
  /// drop" handling for why these are never dropped by a single lower
  /// count alone.
  final List<_BaselineSlot> _baseline = <_BaselineSlot>[];

  /// For an ordinal index beyond [_baseline]'s current length (i.e. not yet
  /// tracked at all - either it's brand new this layout, or its case-1 tail
  /// append is still deferred because an earlier slot was unclean this
  /// layout), the LONGEST fade-tracking text length ever seen rendered at
  /// that index while it remained untracked. A deferred index is still
  /// painted every frame (nothing in [_baseline] backs it, so [_collectDims]
  /// simply has no run to apply and it renders exactly as `gpt_markdown`
  /// itself paints it - fully opaque) - so by the time its append is finally
  /// no longer blocked, some PREFIX of it may already have been genuinely
  /// on screen at full opacity for one or more frames. Arming the WHOLE
  /// text from scratch at that point would dim a prefix a user already saw
  /// fully visible, which is exactly the kind of dip the settled-length
  /// invariant exists to prevent - so case 1 arms only the suffix beyond
  /// this recorded length instead (see [_refresh]). This is keyed by
  /// ORDINAL POSITION ONLY, exactly like every other piece of state in this
  /// design - it never looks at what any OTHER index contains, is populated
  /// and consumed purely as a byproduct of an index's own deferred history,
  /// and is not a persistent cross-document pool (an index's entry is
  /// removed the moment it's finally added to [_baseline]).
  final Map<int, int> _pendingExposedLength = <int, int>{};

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
  ///
  /// See the class doc for the four classification outcomes this applies
  /// per slot, and for why a "settled length" floor makes case-4 (or any
  /// other) misclassification safe by construction.
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

      // A paragraph whose fade-tracking text has NO LETTER at all - pure
      // whitespace, or marker/punctuation debris like `-`, `\n\n-`, a bare
      // digit, `>`, a fence - is never indexed as its own slot. See this
      // method's doc for why; in short, these are exactly gpt_markdown's
      // own transient block-boundary artifacts, they never carry visible
      // WORD content worth fading, and skipping them keeps every REAL
      // slot's ordinal position stable across the artifact's lifetime.
      if (!_hasLetter.hasMatch(fadeText)) continue;

      paintSlots.add(_PaintSlot(para, fadeText.length, indexMap));
      currentTexts.add(fadeText);
    }

    final n = currentTexts.length;
    final nowValue = now();

    // Slot-count drop: fewer paragraphs this layout than the current
    // baseline holds. NEVER truncated by a count drop alone, no matter how
    // many consecutive layouts it persists - only an [epoch] change ever
    // clears these entries (see the class doc's case 4 and the deviation
    // note below). Until then the extra entries are simply left alone: they
    // aren't iterated below (the loop only ever covers
    // `0..existingCount-1`), so they cost nothing and aren't painted (no
    // current paragraph exists for them).
    //
    // **Deliberate deviation from the literal slice brief, evidence-based
    // (documented per this repo's own directive-conflict protocol):** the
    // brief specified truncating after the SAME lower count holds for two
    // consecutive layouts. Empirically (this slice's own
    // `test/widget/markdown_fade_invariant_stale_test.dart` "tbl2"/"mixed"
    // cases, and the pre-existing `markdown_fade_verify5_test.dart`
    // "identical table cells" case), `gpt_markdown` hides a growing table's
    // entire body for EXACTLY two consecutive layouts on every single row
    // it streams in, before the row count returns - which a two-layout
    // threshold truncates every time, discarding every settled row's
    // baseline/run state, so the row reappears as a brand new tail slot and
    // re-fades (or, worse, dips) from scratch on every row addition. This
    // is not a new discovery: `doc/BENCHMARKS.md`'s round-5 section
    // documents this EXACT gpt_markdown behavior and EXPLICITLY rejected a
    // short fixed-N-layout hysteresis for this reason, landing on
    // unconditional retention instead. Reverting to indefinite retention
    // here restores that already-proven behavior; it changes only this one
    // threshold and does not reintroduce any of the cross-slot matching
    // (orphan pool, adjacent-live check, rewrite-with-runs) the brief
    // separately - and correctly - asked to delete.

    final existingCount = n < _baseline.length ? n : _baseline.length;
    var allEarlierOk = true;

    for (var i = 0; i < existingCount; i++) {
      final bs = _baseline[i];

      // Sweep runs that have finished BEFORE diffing, promoting their end
      // into `settledLength` - the hard floor a fresh run can never start
      // below.
      bs.runs.removeWhere((r) {
        if (nowValue - r.revealedAt >= fadeDuration) {
          if (r.end > bs.settledLength) bs.settledLength = r.end;
          return true;
        }
        return false;
      });

      final oldText = bs.text;
      final newText = currentTexts[i];

      if (newText == oldText) {
        bs.pendingText = null;
        bs.pendingCount = 0;
        continue;
      }

      if (newText.length > oldText.length && newText.startsWith(oldText)) {
        // Case 2: growth. Arm exactly the new suffix, clamped to the
        // settled-length floor (normally a no-op clamp - `settledLength`
        // can't exceed `oldText.length` under normal flow - kept as the
        // hard invariant regardless).
        final start =
            oldText.length > bs.settledLength
                ? oldText.length
                : bs.settledLength;
        if (start < newText.length) {
          bs.runs.add(_SlotRun(start, newText.length, nowValue));
        }
        bs.text = newText;
        bs.pendingText = null;
        bs.pendingCount = 0;
        continue;
      }

      // Case 2b: growth from a TRIMMED prefix of the old text - see
      // [_growthPrefixLength]'s doc (a heading's trailing divider-
      // placeholder whitespace, or an inline-markup marker the caught-up
      // widget rendered raw before its close streamed in). Still per-slot,
      // still zero cross-slot matching - this only ever looks at THIS
      // slot's own old/new text.
      final growthPrefix = _growthPrefixLength(
        oldText,
        newText,
        bs.settledLength,
      );
      if (growthPrefix != null) {
        final (trimmed, preserveTiming) = growthPrefix;
        final start = trimmed > bs.settledLength ? trimmed : bs.settledLength;
        // The discarded old suffix (`[trimmed, oldText.length)`) no longer
        // corresponds to anything in `newText` - drop or truncate any run
        // describing it; a run entirely within `[0, trimmed)` is unaffected
        // (that prefix is unchanged, by construction of `trimmed`).
        //
        // For the MARKER trim only (`preserveTiming`), capture the EARLIEST
        // `revealedAt` among the runs actually being discarded (if any)
        // before discarding them - the raw markup this is replacing (e.g.
        // `'**primary'`) can already have been mid-fade for real (a genuine
        // prior growth step armed a run over it, same as any other text),
        // and resetting to `nowValue` here would visibly DIP it back down
        // despite it already having been partway visible - exactly the
        // failure this fix exists to prevent, not reintroduce. Continuing
        // the SAME timeline instead (the word is conceptually "the same
        // one", merely re-styled) means a range already close to fully
        // faded simply stays that way. The WHITESPACE trim never needs
        // this - the suffix beyond a trailing newline is always genuinely
        // brand new content, so it's armed fresh from `nowValue` exactly
        // like ordinary growth.
        Duration? preserveFrom;
        for (final run in bs.runs) {
          if (run.end <= trimmed) continue;
          if (preserveTiming &&
              (preserveFrom == null || run.revealedAt < preserveFrom)) {
            preserveFrom = run.revealedAt;
          }
          run.end = trimmed;
        }
        bs.runs.removeWhere((r) => r.end <= r.start);
        if (start < newText.length) {
          bs.runs.add(
            _SlotRun(start, newText.length, preserveFrom ?? nowValue),
          );
        }
        bs.text = newText;
        bs.pendingText = null;
        bs.pendingCount = 0;
        continue;
      }

      // Case 4: anything else (shrink, rewrite, a non-tail insertion, or a
      // slot whose text otherwise doesn't fit 2/3). Arm NOTHING. Adopt
      // opaque (no run) only once the exact same candidate has been seen
      // on two consecutive layouts.
      allEarlierOk = false;
      if (bs.pendingText == newText) {
        bs.pendingCount += 1;
      } else {
        bs.pendingText = newText;
        bs.pendingCount = 1;
      }
      if (bs.pendingCount >= 2) {
        bs.text = newText;
        bs.runs.clear();
        bs.settledLength = newText.length;
        bs.pendingText = null;
        bs.pendingCount = 0;
      }
    }

    // Case 1: a new slot appended at the tail - only while every earlier
    // slot classified clean (identical/growth) on this SAME layout. If a
    // case-4 candidate is still pending anywhere earlier, the append is
    // deferred entirely (left untracked/unpainted, i.e. opaque) until a
    // later layout where the earlier slots are clean again.
    if (n > _baseline.length && allEarlierOk) {
      for (var i = _baseline.length; i < n; i++) {
        final newText = currentTexts[i];
        final bs = _BaselineSlot(newText);
        // If this exact ordinal index was already being painted, unmasked,
        // for one or more PRIOR frames while its append sat deferred (see
        // [_pendingExposedLength]'s doc), don't re-arm the prefix a user
        // already saw at full opacity - only the genuinely new suffix
        // beyond it.
        final exposed = _pendingExposedLength.remove(i) ?? 0;
        final start = exposed < newText.length ? exposed : newText.length;
        if (start < newText.length) {
          bs.runs.add(_SlotRun(start, newText.length, nowValue));
        }
        bs.settledLength = start;
        _baseline.add(bs);
      }
    }

    // Record, for every index still beyond `_baseline.length` after all of
    // the above (a brand new index this layout, or one whose append just
    // got deferred because an earlier slot was unclean), how much of it is
    // being painted unmasked THIS frame - see [_pendingExposedLength]'s doc.
    for (var i = _baseline.length; i < n; i++) {
      final len = currentTexts[i].length;
      final prev = _pendingExposedLength[i];
      if (prev == null || len > prev) _pendingExposedLength[i] = len;
    }

    _paintSlots = paintSlots;
    _currentTexts = currentTexts;
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
      if (bs.runs.isEmpty) continue;
      final slot = _paintSlots[i];
      final currentText = _currentTexts[i];

      // Paint-time validity: a run only ever describes `bs.text`'s
      // coordinate space (case 2/3 only ever extend it; case 4 always
      // replaces `text` and `runs` together atomically) - if the slot's
      // CURRENT text doesn't still start with `bs.text`, drop every run
      // for this slot this frame entirely. Painting nothing snaps that
      // range to fully opaque, never to alpha 0.
      if (currentText.length < bs.text.length ||
          !currentText.startsWith(bs.text)) {
        continue;
      }

      final para = slot.paragraph;
      if (!para.attached) continue; // defensive; see `_refresh`'s doc.
      final transform = para.getTransformTo(this);
      final localBounds = Offset.zero & para.size;

      for (final run in bs.runs) {
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

        // Runs never cover placeholder characters: split the fade-tracking
        // range into disjoint REAL ranges at every placeholder boundary,
        // so a run can never dim a nested `WidgetSpan`'s own children (see
        // the class doc, failure (1)).
        for (final (realStart, realEnd) in _realRanges(
          slot,
          run.start,
          run.end,
        )) {
          if (realEnd <= realStart) continue;
          final boxes = para.getBoxesForSelection(
            TextSelection(baseOffset: realStart, extentOffset: realEnd),
          );
          if (boxes.isEmpty) continue;
          // `getTransformTo` already folds in any ancestor scroll offset
          // (e.g. a table cell/row scrolled horizontally) between `para`
          // and `this`.
          for (final box in boxes) {
            final rect = box.toRect().intersect(localBounds);
            if (rect.isEmpty) continue;
            dims.add((MatrixUtils.transformRect(transform, rect), progress));
          }
        }
      }
    }
    return dims;
  }

  /// Splits fade-tracking-local `[start, end)` into disjoint REAL-index
  /// ranges, one per maximal contiguous run of real indices, so a range
  /// that spans a stripped placeholder character never includes that
  /// placeholder's own real index (and never asks `getBoxesForSelection`
  /// for a single contiguous span that would otherwise cross it).
  List<(int, int)> _realRanges(_PaintSlot slot, int start, int end) {
    final map = slot.indexMap;
    if (map == null) return [(start, end)];

    final ranges = <(int, int)>[];
    var segStart = -1;
    var prevReal = -1;
    for (var i = start; i < end; i++) {
      final real = slot.toRealIndex(i);
      if (segStart == -1) {
        segStart = real;
      } else if (real != prevReal + 1) {
        ranges.add((segStart, prevReal + 1));
        segStart = real;
      }
      prevReal = real;
    }
    if (segStart != -1) ranges.add((segStart, prevReal + 1));
    return ranges;
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
