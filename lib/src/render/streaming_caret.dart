import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
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
/// Drives no animation itself; the caller supplies [opacity] as a
/// [ValueListenable], typically fed by [caretPulseOpacity] on the host
/// widget's single shared ticker.
///
/// Listening to [opacity] itself (via [ValueListenableBuilder]), rather than
/// receiving a plain `double` and being rebuilt from above on every pulse
/// frame, means the pulse only ever repaints this small subtree: the ticker
/// can update [opacity]'s value every frame without calling `setState` on the
/// whole streaming-text widget (and, in markdown mode, without rebuilding the
/// markdown subtree at all - see `lib/src/render/caret_inline.dart`).
class StreamingCaret extends StatelessWidget {
  /// Creates a caret whose opacity tracks [opacity].
  const StreamingCaret({super.key, required this.opacity, required this.color});

  /// Current caret opacity, clamped to [0.0, 1.0]. Notifies this widget alone
  /// on every pulse frame.
  final ValueListenable<double> opacity;

  /// Caret colour, normally `StreamingTokens.of(brightness).textPrimary`.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: opacity,
      builder: (context, value, _) => SizedBox.square(
        dimension: 8,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: value.clamp(0.0, 1.0)),
          ),
        ),
      ),
    );
  }
}
