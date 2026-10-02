import 'package:characters/characters.dart';

/// Decides how far a [RevealEngine] may advance its cursor in one step.
///
/// A policy never splits a grapheme cluster: every boundary it returns is
/// a valid grapheme boundary in the source string (UTF-16 offset).
abstract class UnitPolicy {
  /// Const constructor for subclasses.
  const UnitPolicy();

  /// Returns the next allowed reveal boundary at or after [from].
  ///
  /// [source] is the full (unmodified) source string. [from] is always a
  /// grapheme boundary at or before `source.length`. [inputClosed] tells
  /// the policy whether more text may still arrive: a policy MUST NOT
  /// advance past a boundary it can't yet prove is final while
  /// `inputClosed` is false (e.g. a word that might still be extended by
  /// the next chunk).
  ///
  /// Returns [from] itself when no further progress can be made yet.
  int nextBoundary(String source, int from, {required bool inputClosed});
}

/// Advances the cursor by up to [chunkSize] graphemes per call.
///
/// `CharPolicy(chunkSize: 1)` is "char" mode; `CharPolicy(chunkSize: n)`
/// with `n > 1` is "chunk" mode.
class CharPolicy extends UnitPolicy {
  /// Creates a char/chunk policy revealing up to [chunkSize] graphemes
  /// per call.
  const CharPolicy({this.chunkSize = 1}) : assert(chunkSize > 0);

  /// Graphemes revealed per [nextBoundary] call (subject to withholding).
  final int chunkSize;

  @override
  int nextBoundary(String source, int from, {required bool inputClosed}) {
    if (from >= source.length) return source.length;
    final range = CharacterRange.at(source, from);
    range.moveNext(chunkSize);
    return range.stringBeforeLength + range.currentCharacters.string.length;
  }
}

/// Reveals nothing while input is open; reveals everything in one step once
/// input closes. Used for the "atomic" / instant reveal mode.
class AtomicPolicy extends UnitPolicy {
  /// Creates an atomic (instant) reveal policy.
  const AtomicPolicy();

  @override
  int nextBoundary(String source, int from, {required bool inputClosed}) {
    return inputClosed ? source.length : from;
  }
}

/// One unit is: leading whitespace + a maximal non-whitespace run + the
/// whitespace that follows it.
///
/// Whitespace is Unicode whitespace only (via [String.trim] semantics); a
/// ZWNJ between letters is never treated as whitespace, so it always stays
/// inside the surrounding word.
///
/// While input is open, a word/whitespace run that reaches the end of the
/// currently-available source is never revealed, because the next chunk
/// might extend it (this is what makes W1/W2/W4 impossible by
/// construction: text is never rewritten or de-indented, only withheld).
class WordPolicy extends UnitPolicy {
  /// Creates a word-by-word reveal policy.
  const WordPolicy();

  @override
  int nextBoundary(String source, int from, {required bool inputClosed}) {
    if (from >= source.length) return source.length;

    final range = CharacterRange.at(source, from);
    var pos = from;

    // 1. Leading whitespace run (usually empty; non-empty only right at the
    //    very start of the source, since every prior unit already consumes
    //    its own trailing whitespace).
    while (range.moveNext()) {
      if (_isWhitespace(range.currentCharacters.string)) {
        pos += range.currentCharacters.string.length;
      } else {
        range.moveBack();
        break;
      }
    }
    if (pos >= source.length) {
      // Nothing but whitespace is available. If input is closed that's the
      // final answer; otherwise more whitespace (or a word) may still be
      // coming, so withhold it.
      return inputClosed ? source.length : from;
    }

    // 1.5. Unspaced CJK (Han/Kana) text has no whitespace to delimit
    // words, so treat it as its own unit: advance up to 2 graphemes at a
    // time. Unlike the latin word run below, this never has to wait on
    // [inputClosed] - each grapheme is already a complete, self-delimiting
    // character that the next chunk can't retroactively merge into a
    // bigger unit - so it can never stall while input is open.
    if (range.moveNext()) {
      final first = range.currentCharacters.string;
      if (_isCjk(first)) {
        var cjkPos = pos + first.length;
        if (range.moveNext()) {
          final second = range.currentCharacters.string;
          if (_isCjk(second)) {
            cjkPos += second.length;
          } else {
            range.moveBack();
          }
        }
        return cjkPos;
      }
      range.moveBack();
    }

    // 2. The word itself: a maximal non-whitespace run.
    var wordClosed = false;
    while (range.moveNext()) {
      if (_isWhitespace(range.currentCharacters.string)) {
        range.moveBack();
        wordClosed = true;
        break;
      }
      pos += range.currentCharacters.string.length;
    }
    if (!wordClosed) {
      // The non-whitespace run runs off the end of what's available: we
      // can't tell whether it's a complete word yet.
      return inputClosed ? source.length : from;
    }

    // 3. Trailing whitespace run: safe to consume in full, since the word
    //    before it is already provably closed.
    while (range.moveNext()) {
      if (_isWhitespace(range.currentCharacters.string)) {
        pos += range.currentCharacters.string.length;
      } else {
        range.moveBack();
        break;
      }
    }
    return pos;
  }
}

bool _isWhitespace(String grapheme) => grapheme.trim().isEmpty;

/// Whether [grapheme]'s base code point falls in a Han (CJK ideograph) or
/// Kana (hiragana/katakana) Unicode block. Used to detect unspaced CJK
/// text, which has no whitespace to delimit word units.
bool _isCjk(String grapheme) {
  if (grapheme.isEmpty) return false;
  final cp = grapheme.runes.first;
  // Hiragana, Katakana (incl. phonetic extensions).
  if (cp >= 0x3040 && cp <= 0x30FF) return true;
  // Halfwidth Katakana.
  if (cp >= 0xFF65 && cp <= 0xFF9F) return true;
  // CJK Unified Ideographs + Extension A + Compatibility Ideographs.
  if (cp >= 0x4E00 && cp <= 0x9FFF) return true;
  if (cp >= 0x3400 && cp <= 0x4DBF) return true;
  if (cp >= 0xF900 && cp <= 0xFAFF) return true;
  // CJK Unified Ideographs Extension B and beyond (supplementary plane).
  if (cp >= 0x20000 && cp <= 0x2FFFF) return true;
  return false;
}
