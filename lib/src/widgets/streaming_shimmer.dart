import 'package:flutter/material.dart';

/// A shimmer/skeleton loading widget for use while waiting for
/// the first LLM token to arrive (TTFT — Time To First Token).
///
/// Renders animated skeleton lines that mimic paragraph text.
/// Uses a pure-Flutter sweep gradient — no external packages required.
///
/// Activated automatically when [StreamingTextMarkdown] is constructed
/// with [isLoading: true].
///
/// Example:
/// ```dart
/// StreamingShimmer(
///   baseColor: Colors.grey.shade300,
///   highlightColor: Colors.grey.shade100,
///   lineCount: 3,
/// )
/// ```
class StreamingShimmer extends StatefulWidget {
  /// Base (dark) color of the shimmer skeleton lines.
  /// Defaults to a muted version of the current theme's onSurface color.
  final Color? baseColor;

  /// Highlight (light) color that sweeps across the skeleton.
  /// Defaults to a lighter version of the base color.
  final Color? highlightColor;

  /// Number of skeleton lines to show. Defaults to 3.
  final int lineCount;

  /// Duration of one shimmer sweep cycle. Defaults to 1.5 seconds.
  final Duration duration;

  /// Width of the widest line as a fraction of available width.
  /// Defaults to 1.0 (full width).
  final double maxLineWidth;

  const StreamingShimmer({
    super.key,
    this.baseColor,
    this.highlightColor,
    this.lineCount = 3,
    this.duration = const Duration(milliseconds: 1500),
    this.maxLineWidth = 1.0,
  });

  @override
  State<StreamingShimmer> createState() => _StreamingShimmerState();
}

class _StreamingShimmerState extends State<StreamingShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  // Width fractions for each skeleton line — feels like real paragraph text
  static const _lineWidths = [1.0, 0.85, 0.65, 0.9, 0.75, 0.5];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
    _animation = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final base = widget.baseColor ??
        colorScheme.onSurface.withAlpha(30); // ~12% opacity
    final highlight = widget.highlightColor ??
        colorScheme.onSurface.withAlpha(10); // ~4% opacity

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(widget.lineCount, (i) {
            final widthFraction =
                _lineWidths[i % _lineWidths.length] * widget.maxLineWidth;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return _ShimmerLine(
                    width: constraints.maxWidth * widthFraction,
                    sweepPosition: _animation.value,
                    baseColor: base,
                    highlightColor: highlight,
                  );
                },
              ),
            );
          }),
        );
      },
    );
  }
}

class _ShimmerLine extends StatelessWidget {
  final double width;
  final double sweepPosition;
  final Color baseColor;
  final Color highlightColor;

  const _ShimmerLine({
    required this.width,
    required this.sweepPosition,
    required this.baseColor,
    required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 14.0,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4.0),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: [
            (sweepPosition - 0.5).clamp(0.0, 1.0),
            sweepPosition.clamp(0.0, 1.0),
            (sweepPosition + 0.5).clamp(0.0, 1.0),
          ],
          colors: [baseColor, highlightColor, baseColor],
        ),
      ),
    );
  }
}
