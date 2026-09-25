import 'package:flutter/widgets.dart';

/// A contiguous range of revealed text that fades in once.
///
/// Offsets are UTF-16 offsets into the revealed text, matching the reveal
/// engine's cursor units. Internal to the package.
class FadeRun {
  /// Creates a fade run covering `text[start..end)` revealed at [revealedAt].
  const FadeRun(this.start, this.end, this.revealedAt);

  /// UTF-16 offset where the run starts.
  final int start;

  /// UTF-16 offset where the run ends (exclusive).
  final int end;

  /// Clock timestamp at which the run was revealed.
  final Duration revealedAt;
}

double _progress(Duration revealedAt, Duration now, Duration fadeDuration) {
  if (fadeDuration <= Duration.zero) return 1.0;
  final elapsed = now - revealedAt;
  if (elapsed <= Duration.zero) return 0.0;
  final t = elapsed.inMicroseconds / fadeDuration.inMicroseconds;
  return t >= 1.0 ? 1.0 : t;
}

TextStyle _fadedStyle(TextStyle style, double opacity) {
  final color = style.color;
  if (color == null || opacity >= 1.0) return style;
  return style.copyWith(color: color.withValues(alpha: opacity));
}

/// Whether any run in [runs] is still fading at [now].
bool hasActiveFade({
  required List<FadeRun> runs,
  required Duration now,
  required Duration fadeDuration,
}) {
  for (final run in runs) {
    if (_progress(run.revealedAt, now, fadeDuration) < 1.0) return true;
  }
  return false;
}

/// Builds one span tree for [text] where settled text is a single prefix
/// span and each still-fading [FadeRun] gets its own span with
/// `color.withValues(alpha: curve(t))`.
///
/// Runs with a null `style.color` cannot fade and render opaque. The fade
/// is opacity only; no translate, scale or blur. Runs in O(runs).
InlineSpan buildFadeSpan({
  required String text,
  required List<FadeRun> runs,
  required Duration now,
  required Duration fadeDuration,
  required Curve curve,
  required TextStyle style,
}) {
  final sorted = List<FadeRun>.of(runs)
    ..sort((a, b) => a.start.compareTo(b.start));

  final firstActive = sorted.indexWhere(
    (run) => _progress(run.revealedAt, now, fadeDuration) < 1.0,
  );
  if (firstActive == -1) {
    return TextSpan(text: text, style: style);
  }

  final children = <InlineSpan>[];
  var cursor = sorted[firstActive].start.clamp(0, text.length);
  if (cursor > 0) {
    children.add(TextSpan(text: text.substring(0, cursor), style: style));
  }
  for (final run in sorted.skip(firstActive)) {
    final start = run.start.clamp(0, text.length);
    final end = run.end.clamp(start, text.length);
    if (end <= cursor) continue;
    final t = _progress(run.revealedAt, now, fadeDuration);
    if (t >= 1.0) continue;
    final s = start < cursor ? cursor : start;
    if (s > cursor) {
      children.add(TextSpan(text: text.substring(cursor, s), style: style));
    }
    children.add(TextSpan(
      text: text.substring(s, end),
      style: _fadedStyle(style, curve.transform(t).clamp(0.0, 1.0)),
    ));
    cursor = end;
  }
  if (cursor < text.length) {
    children.add(TextSpan(text: text.substring(cursor), style: style));
  }
  return TextSpan(style: style, children: children);
}
