/// Withholds a trailing INCOMPLETE ``` code fence from the markdown
/// *render* while it's still being typed. Identity once [isComplete] is
/// true, or once the fences in [text] already balance.
///
/// This only affects what gets handed to `GptMarkdown` for display — the
/// caller's own source/cursor bookkeeping (typing position, progress,
/// resume-from-index, ...) must stay untouched.
///
/// Without this, an in-progress fence's raw backtick characters render as
/// literal unstyled text while they're being typed. The instant the closing
/// ``` completes, `GptMarkdown` recognizes the block and reformats it as a
/// styled code block, which strips those fence markers from the visible
/// output — the rendered text visibly shrinks by a few characters at that
/// exact moment, reading as a stutter on top of the typing animation.
/// Holding the render at the last point before an open fence (and releasing
/// the whole block only once it's balanced) means the block only ever
/// appears in its final, styled form, growing normally.
String withholdOpenFence(String text, {required bool isComplete}) {
  if (isComplete) return text;
  final fenceCount = '```'.allMatches(text).length;
  if (fenceCount.isEven) return text;
  return text.substring(0, text.lastIndexOf('```'));
}
