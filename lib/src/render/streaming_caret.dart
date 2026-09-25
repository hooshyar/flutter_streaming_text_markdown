import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Duration of one caret pulse cycle (DESIGN.md `caretPulse`).
const Duration caretPulseDuration = Duration(milliseconds: 900);

/// Minimum opacity the caret pulses down to.
const double caretPulseMinOpacity = 0.35;

/// Opacity of the caret [elapsed] into the pulse cycle.
///
/// Sine in-out between [caretPulseMinOpacity] and 1.0 over
/// [caretPulseDuration]. Always 1.0 when [reducedMotion] is true.
double caretPulseOpacity(Duration elapsed, {bool reducedMotion = false}) {
  if (reducedMotion) return 1.0;
  final phase = (elapsed.inMicroseconds % caretPulseDuration.inMicroseconds) /
      caretPulseDuration.inMicroseconds;
  final wave = 0.5 - 0.5 * math.cos(2 * math.pi * phase);
  return caretPulseMinOpacity + (1.0 - caretPulseMinOpacity) * wave;
}

/// An 8x8 circular caret rendered inline after the last revealed glyph.
///
/// Drives no animation itself; the caller supplies [opacity], typically
/// from [caretPulseOpacity] on the widget's single fade ticker.
class StreamingCaret extends StatelessWidget {
  /// Creates a caret with the given [opacity] and [color].
  const StreamingCaret({super.key, this.opacity = 1.0, required this.color});

  /// Current caret opacity, clamped to [0.0, 1.0].
  final double opacity;

  /// Caret colour, normally `StreamingTokens.of(brightness).textPrimary`.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity.clamp(0.0, 1.0)),
        ),
      ),
    );
  }
}
