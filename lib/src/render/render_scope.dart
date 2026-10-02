import 'package:flutter/widgets.dart';

/// An [InheritedWidget] exposing the current reveal's lifecycle state and
/// caret builder to descendants of [StreamingMarkdownView].
///
/// This is a seam for Phase B2 (not consumed by anything in Phase B1 yet):
/// a future block-level renderer can read `StreamingRenderScope.of(context)`
/// instead of threading `isStreaming`/`isComplete`/the caret builder through
/// every intermediate widget by hand.
class StreamingRenderScope extends InheritedWidget {
  /// Wraps [child], publishing [isStreaming], [isComplete] and
  /// [caretBuilder] to descendants.
  const StreamingRenderScope({
    super.key,
    required this.isStreaming,
    required this.isComplete,
    this.caretBuilder,
    required super.child,
  });

  /// Whether the reveal is actively receiving/animating more content.
  final bool isStreaming;

  /// Whether the reveal has finished (the rendered text equals the full
  /// source and no more input is expected).
  final bool isComplete;

  /// Builds the caret widget currently in use, or `null` when no caret is
  /// shown (see [StreamingText.showCursor]/[StreamingText._caretVisible]).
  final Widget Function()? caretBuilder;

  /// Returns the nearest enclosing [StreamingRenderScope], or `null` when
  /// there isn't one.
  static StreamingRenderScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<StreamingRenderScope>();
  }

  /// Returns the nearest enclosing [StreamingRenderScope]. Throws in debug
  /// mode when there isn't one.
  static StreamingRenderScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'No StreamingRenderScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(StreamingRenderScope oldWidget) {
    return isStreaming != oldWidget.isStreaming ||
        isComplete != oldWidget.isComplete ||
        !identical(caretBuilder, oldWidget.caretBuilder);
  }
}
