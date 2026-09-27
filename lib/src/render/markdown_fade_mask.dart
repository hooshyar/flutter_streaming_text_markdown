import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'fade_span.dart';

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
/// **Coordinate mapping.** [runsOf] returns [FadeRun]s in the *reveal
/// engine's* source-text coordinates (`RevealEngine.runs`/`.cursor`), not
/// the rendered paragraph's plain text - `gpt_markdown` strips markdown
/// syntax and `mend()` can hold back an incomplete trailing marker, so the
/// two texts are not offset-for-offset identical. Both grow in lockstep at
/// the *tail* while streaming though, which is the only place an active run
/// can ever be (older runs are always already settled/opaque), so each run
/// is mapped onto the rendered paragraph by *distance from the end*
/// (`engineLength - run.start`/`.end`) rather than by absolute offset. A run
/// whose distance-from-end exceeds the rendered paragraph's own length
/// (i.e. `mend()` is still withholding it) is skipped outright rather than
/// mis-painted near offset zero.
class MarkdownFadeMask extends SingleChildRenderObjectWidget {
  /// Creates a markdown trailing-fade mask around [child].
  const MarkdownFadeMask({
    super.key,
    required Widget super.child,
    required this.enabled,
    required this.runsOf,
    required this.engineLengthOf,
    required this.now,
    required this.fadeDuration,
    required this.curve,
    required this.repaint,
  });

  /// Whether the mask is active at all. `false` paints [child] unmodified,
  /// with zero extra cost.
  final bool enabled;

  /// The reveal engine's current fade runs (source-text coordinates).
  final List<FadeRun> Function() runsOf;

  /// The reveal engine's current cursor (source-text length so far).
  final int Function() engineLengthOf;

  /// The shared fade clock (matches [FadeRun.revealedAt]'s units).
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
      runsOf: runsOf,
      engineLengthOf: engineLengthOf,
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
      ..runsOf = runsOf
      ..engineLengthOf = engineLengthOf
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
    required this.runsOf,
    required this.engineLengthOf,
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

  // `paint` conditionally calls `context.pushLayer` (only on a frame with an
  // active fade) - report compositing eligibility for the whole time
  // masking is enabled, not just on frames that actually push a layer, so
  // ancestors never see a mid-stream flip they weren't told about.
  @override
  bool get alwaysNeedsCompositing => _enabled;

  /// See [MarkdownFadeMask.runsOf].
  List<FadeRun> Function() runsOf;

  /// See [MarkdownFadeMask.engineLengthOf].
  int Function() engineLengthOf;

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
  int _paragraphTextLength = 0;

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

  /// Finds the last (paint-order) [RenderParagraph] in [child]'s subtree.
  ///
  /// Only run from [performLayout] - i.e. only when [child]'s actual
  /// content/shape changed - never from a ticker-only [paint] pass, so a
  /// pure fade-settling frame never re-walks the whole render tree.
  void _refreshLastParagraph() {
    final c = child;
    if (c == null) {
      _lastParagraph = null;
      _paragraphTextLength = 0;
      return;
    }
    RenderParagraph? found;
    void visit(RenderObject node) {
      if (node is RenderParagraph) found = node;
      node.visitChildren(visit);
    }

    visit(c);
    _lastParagraph = found;
    _paragraphTextLength = found?.text.toPlainText().length ?? 0;
  }

  /// Every still-fading run's local-to-[paragraph] rect(s) and alpha, oldest
  /// run first. Exposed (read-only) purely so tests can assert the fade
  /// curve directly - without screenshots - instead of only through
  /// [paint]'s side effects. Not used by [paint] itself for the rect union
  /// (see [_dimsIn]), only for the paragraph/total-length pair it shares.
  @visibleForTesting
  List<(Rect rect, double alpha)> debugActiveDims() {
    final paragraph = _lastParagraph;
    if (paragraph == null || !paragraph.attached) return const [];
    return _dimsIn(paragraph, _paragraphTextLength);
  }

  List<(Rect rect, double alpha)> _dimsIn(
    RenderParagraph paragraph,
    int total,
  ) {
    if (total <= 0) return const [];
    final nowValue = now();
    final engineLength = engineLengthOf();

    // Collect every still-fading run's (rect, alpha) pair FIRST, across the
    // whole run list, and apply them in a single paint pass below. Painting
    // [child] once per run (each a fresh, fully-opaque paint) would make
    // each later pass overwrite the dimming an earlier pass applied
    // elsewhere - it must be painted exactly once per frame.
    final dims = <(Rect, double)>[];
    for (final run in runsOf()) {
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

      final suffixEnd = engineLength - run.start;
      final suffixStart = engineLength - run.end;
      if (suffixEnd <= 0) {
        // This run has already scrolled entirely past the paragraph
        // boundary into an already-settled earlier block.
        continue;
      }
      // `suffixEnd` can legitimately exceed `total` by a character or two -
      // e.g. a trailing space `mend()`/`gpt_markdown` collapse out of the
      // rendered plain text entirely while the engine still counts it -
      // without that meaning the run is unrendered; clamp it down to "the
      // very end of what's actually there" instead of skipping the run.
      final clampedSuffixEnd = suffixEnd > total ? total : suffixEnd;
      final renderStart = (total - clampedSuffixEnd).clamp(0, total);
      final renderEnd = (total - suffixStart).clamp(0, total);
      if (renderEnd <= renderStart) continue;

      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: renderStart, extentOffset: renderEnd),
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

    final dims = _dimsIn(paragraph, _paragraphTextLength);
    if (dims.isEmpty) {
      context.paintChild(c, offset);
      return;
    }

    final transform = paragraph.getTransformTo(this);
    final mapped = [
      for (final (box, progress) in dims)
        (MatrixUtils.transformRect(transform, box).shift(offset), progress),
    ];
    _paintNested(context, offset, c, mapped, 0);
  }

  /// Paints [c] wrapped in one nested [ShaderMaskLayer] per entry in
  /// [dims], each localized (via its own `maskRect`) to a single fading
  /// run's box. [c] itself is only ever painted once, at the innermost
  /// level - the outer layers are cheap compositing wrappers around that
  /// one paint, not repeated traversals of [c]'s subtree.
  ///
  /// Deliberately goes through [PaintingContext.pushLayer] (rather than
  /// raw `canvas.saveLayer`/`restore`) so a repaint boundary anywhere in
  /// [c]'s subtree is handled by the framework's own layer plumbing instead
  /// of risking an orphaned mid-picture canvas.
  void _paintNested(
    PaintingContext context,
    Offset offset,
    RenderBox c,
    List<(Rect, double)> dims,
    int index,
  ) {
    if (index >= dims.length) {
      context.paintChild(c, offset);
      return;
    }
    final (maskRect, progress) = dims[index];
    final color = Color.fromRGBO(0, 0, 0, progress);
    // A uniform (both stops equal) gradient: it's just a flat `progress`
    // alpha over the whole `maskRect`, not a directional fade - only the
    // rect's *bounds* matter for localizing the effect. Per [ShaderMaskLayer
    // .shader]'s doc, the shader's own coordinate origin is `maskRect`'s
    // top-left, not the canvas origin.
    final layer =
        ShaderMaskLayer()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(maskRect.width, maskRect.height),
            [color, color],
          )
          ..maskRect = maskRect
          ..blendMode = BlendMode.dstIn;
    context.pushLayer(
      layer,
      (innerContext, innerOffset) =>
          _paintNested(innerContext, innerOffset, c, dims, index + 1),
      offset,
    );
  }
}
