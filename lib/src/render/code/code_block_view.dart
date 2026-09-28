import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/code_block_theme.dart';
import 'code_highlighter.dart';

/// A self-contained code block: optional header (language label + copy
/// button) above horizontally-scrollable, syntax-highlighted code.
///
/// Ported from `flutter_gen_ai_chat_ui`'s `CodeBlockView` (see
/// PHASE-B2-LEAN.md S1) and adapted to stand alone - this package renders
/// fenced code through `gpt_markdown`'s `codeBuilder` hook rather than a
/// `flutter_markdown_plus` element builder, so there is no
/// `CodeBlockMarkdownBuilder` counterpart here.
///
/// The widget always renders its content left-to-right so code stays LTR
/// inside RTL messages.
class CodeBlockView extends StatefulWidget {
  /// Creates a code block view.
  const CodeBlockView({
    super.key,
    required this.code,
    this.language,
    this.theme,
    this.enableSyntaxHighlighting = true,
    this.showCopyButton = true,
    this.closed = true,
    this.baseStyle,
    this.padding,
    this.decorate = true,
  });

  /// Raw source code - no markdown fences or language tag.
  final String code;

  /// Language tag used for highlighting and shown lowercase in the header.
  final String? language;

  /// Visual theme. Defaults to [CodeBlockTheme.of] with ambient brightness.
  final CodeBlockTheme? theme;

  /// When false the code renders as a single unhighlighted span.
  final bool enableSyntaxHighlighting;

  /// Whether the header shows a copy affordance at all. When [closed] is
  /// `false` the affordance's space is still reserved (so the header never
  /// changes height) but it is disabled and invisible - see [closed].
  final bool showCopyButton;

  /// Whether the fenced block this view renders has finished streaming.
  ///
  /// While `false` (a growing block whose closing ``` hasn't arrived yet)
  /// the copy button is disabled and hidden - copying a block that's still
  /// being written would copy an incomplete snippet - but the same-size
  /// slot stays reserved so the header doesn't change height, and therefore
  /// the code area doesn't jump, the moment the block closes.
  final bool closed;

  /// Optional override merged over `theme.baseStyle` (font family, size,
  /// colour, ...). Its `backgroundColor` is ignored - backgrounds belong to
  /// the container.
  final TextStyle? baseStyle;

  /// Inner padding around the code. Defaults to
  /// `EdgeInsets.symmetric(vertical: 14, horizontal: 16)`.
  final EdgeInsets? padding;

  /// Whether to paint the rounded background/border container.
  final bool decorate;

  @override
  State<CodeBlockView> createState() => _CodeBlockViewState();
}

class _CodeBlockViewState extends State<CodeBlockView> {
  static const Duration _copiedFeedbackDuration = Duration(milliseconds: 1500);

  final ScrollController _scrollController = ScrollController();
  final CodeHighlighter _highlighter = const CodeHighlighter();

  bool _copied = false;
  Timer? _copiedTimer;

  /// Whether there is more code to scroll to at the right edge.
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateCanScrollRight);
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    _scrollController.removeListener(_updateCanScrollRight);
    _scrollController.dispose();
    super.dispose();
  }

  /// `widget.code` with exactly one trailing newline removed.
  ///
  /// Fenced blocks often hand us content ending with a `\n` from the
  /// closing fence line - rendering it as-is adds a whole blank trailing
  /// line (most visible as dead space below one-line blocks). Only a
  /// single trailing `\r\n`/`\n` is stripped (not `trimRight()`, which
  /// would also eat intentional trailing blank lines a caller passed on
  /// purpose) and the same trimmed string is what gets copied, so copy
  /// output matches what's on screen.
  String get _displayCode {
    final code = widget.code;
    if (code.endsWith('\r\n')) return code.substring(0, code.length - 2);
    if (code.endsWith('\n')) return code.substring(0, code.length - 1);
    return code;
  }

  void _updateCanScrollRight() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final canScrollRight = position.pixels < position.maxScrollExtent - 1;
    if (canScrollRight != _canScrollRight) {
      setState(() => _canScrollRight = canScrollRight);
    }
  }

  Future<void> _copy() async {
    if (!widget.closed) return;
    await Clipboard.setData(ClipboardData(text: _displayCode));
    if (!mounted) return;
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(_copiedFeedbackDuration, () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  /// Merges [CodeBlockView.baseStyle] over [theme]'s `baseStyle`, dropping
  /// any `backgroundColor`. `copyWith` cannot null out a field, so the
  /// merged style is rebuilt field-by-field (the `fontFamily` getter
  /// already returns the `packages/<pkg>/` prefixed value, so nothing is
  /// lost).
  TextStyle _effectiveBaseStyle(CodeBlockTheme theme) {
    final override = widget.baseStyle;
    if (override == null) return theme.baseStyle;
    final merged = theme.baseStyle.merge(override);
    if (merged.backgroundColor == null) return merged;
    return TextStyle(
      inherit: merged.inherit,
      color: merged.color,
      fontSize: merged.fontSize,
      fontWeight: merged.fontWeight,
      fontStyle: merged.fontStyle,
      letterSpacing: merged.letterSpacing,
      wordSpacing: merged.wordSpacing,
      textBaseline: merged.textBaseline,
      height: merged.height,
      leadingDistribution: merged.leadingDistribution,
      locale: merged.locale,
      foreground: merged.foreground,
      background: merged.background,
      shadows: merged.shadows,
      fontFeatures: merged.fontFeatures,
      fontVariations: merged.fontVariations,
      decoration: merged.decoration,
      decorationColor: merged.decorationColor,
      decorationStyle: merged.decorationStyle,
      decorationThickness: merged.decorationThickness,
      debugLabel: merged.debugLabel,
      fontFamily: merged.fontFamily,
      fontFamilyFallback: merged.fontFamilyFallback,
      overflow: merged.overflow,
    );
  }

  CodeBlockTheme _effectiveTheme(CodeBlockTheme theme) {
    final baseStyle = _effectiveBaseStyle(theme);
    if (identical(baseStyle, theme.baseStyle)) return theme;
    return CodeBlockTheme(
      backgroundColor: theme.backgroundColor,
      borderColor: theme.borderColor,
      headerTextColor: theme.headerTextColor,
      baseStyle: baseStyle,
      commentColor: theme.commentColor,
      stringColor: theme.stringColor,
      numberColor: theme.numberColor,
      keywordColor: theme.keywordColor,
      typeColor: theme.typeColor,
      functionColor: theme.functionColor,
      annotationColor: theme.annotationColor,
      punctuationColor: theme.punctuationColor,
      copyTooltip: theme.copyTooltip,
      copiedTooltip: theme.copiedTooltip,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _effectiveTheme(
      widget.theme ?? CodeBlockTheme.of(Theme.of(context).brightness),
    );
    final language = widget.language?.trim() ?? '';
    final hasHeader = language.isNotEmpty || widget.showCopyButton;

    // The scroll extent is only known after this frame lays out; schedule a
    // check so the edge fade appears/disappears as soon as it's accurate
    // (e.g. when `code` changes length between builds).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateCanScrollRight();
    });

    Widget codeArea = Scrollbar(
      controller: _scrollController,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding:
            widget.padding ??
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Text.rich(
          _highlighter.highlight(
            _displayCode,
            language: widget.language,
            theme: theme,
            enabled: widget.enableSyntaxHighlighting,
          ),
          softWrap: false,
        ),
      ),
    );

    if (_canScrollRight) {
      codeArea = ShaderMask(
        shaderCallback:
            (bounds) => const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [0, 0.94, 1],
              colors: [Colors.white, Colors.white, Colors.transparent],
            ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: codeArea,
      );
    }

    Widget child = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasHeader) ...[
          _Header(
            language: language,
            theme: theme,
            copied: _copied,
            showCopyButton: widget.showCopyButton,
            closed: widget.closed,
            onCopy: _copy,
          ),
          Container(height: 1, color: theme.borderColor),
        ],
        codeArea,
      ],
    );

    if (widget.decorate) {
      child = Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: theme.backgroundColor,
          border: Border.all(color: theme.borderColor, width: 1),
          borderRadius: BorderRadius.circular(_radius),
        ),
        child: child,
      );
    }

    return Directionality(textDirection: TextDirection.ltr, child: child);
  }
}

/// Corner radius for the code block container. Matches
/// `flutter_gen_ai_chat_ui`'s `ChatRadius.md` token (DESIGN.md code-block
/// radius); kept as a local constant since this package's own token set
/// (`StreamingTokens`) doesn't carry a radius scale yet.
const double _radius = 12;

class _Header extends StatelessWidget {
  const _Header({
    required this.language,
    required this.theme,
    required this.copied,
    required this.showCopyButton,
    required this.closed,
    required this.onCopy,
  });

  final String language;
  final CodeBlockTheme theme;
  final bool copied;
  final bool showCopyButton;
  final bool closed;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final tooltip = copied ? theme.copiedTooltip : theme.copyTooltip;
    // Reduced-motion: skip the icon-swap animation entirely when the
    // platform requests fewer animations.
    final reducedMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 12, end: 0),
        child: Row(
          children: [
            if (language.isNotEmpty)
              Expanded(
                child: Text(
                  language.toLowerCase(),
                  style: theme.baseStyle.copyWith(
                    color: theme.headerTextColor,
                    fontSize: 12,
                    letterSpacing: 0.2,
                  ),
                ),
              )
            else
              const Spacer(),
            if (showCopyButton)
              // `maintainSize` keeps the button's footprint reserved while
              // `closed` is false, so the header never changes height (and
              // the code area beneath it never jumps) the instant the
              // fence closes and the button becomes visible/enabled.
              Visibility(
                visible: closed,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: Semantics(
                  button: true,
                  label: tooltip,
                  child: IconButton(
                    tooltip: closed ? tooltip : null,
                    onPressed: closed ? onCopy : null,
                    iconSize: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    color: theme.headerTextColor,
                    icon: AnimatedSwitcher(
                      duration:
                          reducedMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 150),
                      child: Icon(
                        copied ? Icons.check_rounded : Icons.copy_rounded,
                        key: ValueKey(copied),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
