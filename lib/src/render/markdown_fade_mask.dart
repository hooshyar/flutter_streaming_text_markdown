import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// One still-fading range of the last [RenderParagraph]'s OWN rendered plain
/// text (never source-text coordinates - see [RenderMarkdownFadeMask]'s doc
/// for why that distinction is load-bearing).
class _MaskRun {
  const _MaskRun(this.start, this.end, this.revealedAt);
  final int start;
  final int end;
  final Duration revealedAt;
}

/// Paints a cheap word-fade over the trailing text of the last
/// [RenderParagraph] found in [child]'s subtree, without ever rebuilding or
/// re-laying-out [child] itself.
///
/// **Why this exists (B1-S6, doc/BENCHMARKS.md "Reveal delegation
/// decision"/"B1-S5 correction"):** `gpt_markdown`'s own `animation: fade`
/// restyles its whole segment cache every tick - 2.1-2.2x time, 13x element
/// rebuilds against a 1.8x/6x budget. This widget instead finds the exact
/// on-screen box(es) of the still-fading suffix and dims *only those pixels*
/// with one extra full paint of [child] plus one `BlendMode.dstIn` rect draw
/// per still-fading run. It never touches an `Element`, never calls
/// `setState` on [child]'s subtree, and never re-runs layout - purely a
/// paint-time effect driven by [repaint] (typically the same ticker that
/// already drives the caret/plain-text fade).
///
/// **Coordinate mapping (fixed after a verify-round-2 pixel regression).**
/// An earlier version of this mask mapped the reveal engine's fade runs
/// (source-text coordinates) onto the rendered paragraph by *distance from
/// the end*, assuming the source and rendered texts grow in lockstep at the
/// tail. They don't: `gpt_markdown` strips markdown syntax entirely (a
/// `**word**` source run is 4 characters longer than its rendered `word`;
/// a `[text](url)` link can be dozens of characters longer than its
/// rendered `text`), so appending one made the tail's "distance from the
/// end" jump for every run behind it too, dimming already-settled words or
/// (for a long link) an entire preceding line.
///
/// This version never looks at source-text coordinates at all. Every time
/// [performLayout] observes the last [RenderParagraph]'s own
/// `text.toPlainText().length` grow, it records a [_MaskRun] spanning
/// exactly `[oldRenderedLength, newRenderedLength)` at the current time -
/// i.e. purely in the paragraph's own coordinate space, using the
/// paragraph's actual rendered growth as the signal instead of trying to
/// re-derive it from the source. If the last paragraph's *identity* changes
/// (a new block started), tracking resets instead of carrying stale offsets
/// into an unrelated paragraph or fading anything in an older, already-
/// settled one.
class MarkdownFadeMask extends SingleChildRenderObjectWidget {
  /// Creates a markdown trailing-fade mask around [child].
  const MarkdownFadeMask({
    super.key,
    required Widget super.child,
    required this.enabled,
    required this.now,
    required this.fadeDuration,
    required this.curve,
    required this.repaint,
  });

  /// Whether the mask is active at all. `false` paints [child] unmodified,
  /// with zero extra cost.
  final bool enabled;

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
      ..now = now
      ..fadeDuration = fadeDuration
      ..curve = curve
      ..repaint = repaint;
  }
}

/// The [RenderObject] behind [MarkdownFadeMask]. See that class's doc for
/// the approach and why it stays paint-only.
class RenderMarkdownFadeMask extends RenderProxyBox {
  /// Creates the render object. See [MarkdownFadeMask]'s fields.
  RenderMarkdownFadeMask({
    required bool enabled,
    required this.now,
    required this.fadeDuration,
    required this.curve,
    required Listenable repaint,
  }) : _enabled = enabled,
       _repaint = repaint;

  bool _enabled;

  /// Whether the mask is active. Toggling only ever triggers a repaint.
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  // `paint` conditionally calls `context.canvas.saveLayer` (only on a frame
  // with an active fade) - report compositing eligibility for the whole
  // time masking is enabled, not just on frames that actually use a layer,
  // so ancestors never see a mid-stream flip they weren't told about.
  @override
  bool get alwaysNeedsCompositing => _enabled;

  /// See [MarkdownFadeMask.now].
  Duration Function() now;

  /// See [MarkdownFadeMask.fadeDuration].
  Duration fadeDuration;

  /// See [MarkdownFadeMask.curve].
  Curve curve;

  Listenable _repaint;

  /// See [MarkdownFadeMask.repaint].
  set repaint(Listenable value) {
    if (identical(value, _repaint)) return;
    if (attached) _repaint.removeListener(markNeedsPaint);
    _repaint = value;
    if (attached) _repaint.addListener(markNeedsPaint);
  }

  RenderParagraph? _lastParagraph;
  int _lastParagraphLength = 0;
  final List<_MaskRun> _pendingRuns = <_MaskRun>[];

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
  void performLayout() {
    super.performLayout();
    _refreshLastParagraph();
  }

  /// Finds the last (paint-order) [RenderParagraph] in [child]'s subtree
  /// and records any growth as a new [_MaskRun].
  ///
  /// Only run from [performLayout] - i.e. only when [child]'s actual
  /// content/shape changed - never from a ticker-only [paint] pass, so a
  /// pure fade-settling frame never re-walks the whole render tree.
  void _refreshLastParagraph() {
    final c = child;
    RenderParagraph? found;
    if (c != null) {
      void visit(RenderObject node) {
        if (node is RenderParagraph) found = node;
        node.visitChildren(visit);
      }

      visit(c);
    }

    if (!identical(found, _lastParagraph)) {
      // The last paragraph's very IDENTITY changed - either this is the
      // very FIRST paragraph this mask has ever seen (nothing to protect;
      // its whole initial content is genuinely brand new, exactly like the
      // very first revealed word of plain text), or a new block started /
      // `gpt_markdown` rebuilt this region's render objects mid-stream
      // (there COULD be a lot of already-settled text folded into the new
      // paragraph object, e.g. a restructured table - fading all of that
      // on a bare identity swap is exactly the "flash-refades settled
      // content" failure mode this file was rewritten to avoid, so that
      // case starts tracking fresh with NO run instead).
      //
      // Either way, offsets never carry across unrelated `RenderParagraph`s
      // (their coordinate spaces have nothing to do with each other), and
      // an older paragraph is never touched again once it stops being
      // `_lastParagraph`.
      final isFirstParagraphEver = _lastParagraph == null;
      _lastParagraph = found;
      _pendingRuns.clear();
      final newLength = found?.text.toPlainText().length ?? 0;
      if (isFirstParagraphEver && newLength > 0) {
        _pendingRuns.add(_MaskRun(0, newLength, now()));
      }
      _lastParagraphLength = newLength;
      return;
    }

    final newLength = found?.text.toPlainText().length ?? 0;
    if (newLength > _lastParagraphLength) {
      _pendingRuns.add(_MaskRun(_lastParagraphLength, newLength, now()));
    }
    // A shrink (e.g. the caret's trailing placeholder character disappearing
    // on completion) is never treated as a fade - just re-baseline silently.
    _lastParagraphLength = newLength;

    // Prune runs that can no longer be active, so a long-running stream
    // never accumulates an unbounded backlog of settled runs.
    final cutoff = now() - fadeDuration;
    _pendingRuns.removeWhere((r) => r.revealedAt <= cutoff);
  }

  /// Every still-fading run's local-to-this-render-object rect(s) and
  /// alpha, oldest run first. Exposed (read-only) purely so tests can
  /// assert the fade curve directly - without screenshots - instead of only
  /// through [paint]'s side effects.
  @visibleForTesting
  List<(Rect rect, double alpha)> debugActiveDims() {
    final paragraph = _lastParagraph;
    if (paragraph == null || !paragraph.attached) return const [];
    return _dims(paragraph);
  }

  List<(Rect rect, double alpha)> _dims(RenderParagraph paragraph) {
    if (_pendingRuns.isEmpty) return const [];
    final nowValue = now();
    final dims = <(Rect, double)>[];
    for (final run in _pendingRuns) {
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

      final start = run.start.clamp(0, _lastParagraphLength);
      final end = run.end.clamp(start, _lastParagraphLength);
      if (end <= start) continue;

      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: end),
      );
      for (final box in boxes) {
        dims.add((box.toRect(), progress));
      }
    }
    return dims;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final c = child;
    if (c == null) return;

    if (!_enabled) {
      context.paintChild(c, offset);
      return;
    }

    final paragraph = _lastParagraph;
    if (paragraph == null || !paragraph.attached) {
      context.paintChild(c, offset);
      return;
    }

    final dims = _dims(paragraph);
    if (dims.isEmpty) {
      context.paintChild(c, offset);
      return;
    }

    final transform = paragraph.getTransformTo(this);
    // One full paint of [c] (same cost as bare), then dim each fading box
    // in place, all within a SINGLE compositing layer - not one nested
    // layer per box (up to ~32, one per `RevealEngine` run kept), which is
    // what an earlier version of this file did and what made verify flag
    // it as unnecessarily heavy compositing.
    context.canvas.saveLayer(offset & size, Paint());
    context.paintChild(c, offset);
    for (final (box, progress) in dims) {
      final mapped = MatrixUtils.transformRect(transform, box).shift(offset);
      context.canvas.drawRect(
        mapped,
        Paint()
          ..color = Color.fromRGBO(0, 0, 0, progress)
          ..blendMode = BlendMode.dstIn,
      );
    }
    context.canvas.restore();
  }
}
