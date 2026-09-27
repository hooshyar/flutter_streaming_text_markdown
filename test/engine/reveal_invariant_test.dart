// A seeded-random property test: for every corpus string, every unit
// policy, and every way of splitting that string into chunks (including
// splits that land mid-surrogate-pair or mid-grapheme-cluster), the
// RevealEngine must always end up with revealed == source, every
// intermediate `revealed` must be a literal prefix of source, the cursor
// must never sit inside a grapheme cluster or an atomic span, progress
// must be monotonic non-decreasing, and onComplete must fire exactly once.
//
// This directly targets W1, W2, W4, W5, W6 and W24.

import 'dart:math';

import 'package:characters/characters.dart';
import 'package:flutter_streaming_text_markdown/src/engine/atomic_spans.dart';
import 'package:flutter_streaming_text_markdown/src/engine/reveal_engine.dart';
import 'package:flutter_streaming_text_markdown/src/engine/unit_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adversarial corpus: surrogate pairs, emoji ZWJ sequences, Arabic with
/// ZWNJ, CRLF, tabs, indented code, and LaTeX spans next to fenced `$`
/// code.
final _corpus = <String>[
  // Plain ASCII with mixed whitespace.
  'hello world, this is   a   test.',
  // Surrogate pairs (astral-plane characters): 𝔘𝔫𝔦𝔠𝔬𝔡𝔢 (U+1D518 etc).
  'math: 𝔘𝔫𝔦𝔠𝔬𝔡𝔢 𝔰𝔱𝔯𝔦𝔫𝔤 𝔱𝔢𝔰𝔱',
  // Emoji ZWJ sequences (family, and flags via regional indicators).
  'team 👨‍👩‍👧‍👦 ready, flags 🏳️‍🌈 🇺🇳 and plain 😀 emoji',
  // Arabic with ZWNJ (U+200C) breaking letter joins mid-word.
  'مرحبا ب‌ك في التطبيق، هذا اختبار عربي',
  // CRLF line endings.
  'line one\r\nline two\r\nline three\r\n',
  // Tabs.
  '\tindented\twith\ttabs\tand\tmore',
  // Indented code block.
  '```dart\n'
      'void main() {\n'
      '  print("hi");\n'
      '    if (true) {\n'
      '      nested();\n'
      '    }\n'
      '}\n'
      '```',
  // LaTeX spans next to a fenced `\$` shell code block (W11 territory).
  'Euler: \$e^{i\\pi}+1=0\$ and block \$\$\\int_0^1 x\\,dx\$\$ then code:\n'
      '```bash\n'
      'echo "cost is \$COST and total is \$TOTAL"\n'
      '```\n'
      'and inline `\$NOT_LATEX` too, plus \\(a+b\\) and \\[c+d\\].',
  // Mixed: RTL + emoji + LaTeX + CRLF all in one.
  'عربي ‌مع 👨‍👩‍👧 و \$x^2\$\r\nnext line\ttabbed',
  // A stray, unbalanced `\$` in an otherwise-finished document: with LaTeX
  // atomic spans enabled this must never stall completion once input is
  // closed (there is no more text coming that could ever close it).
  'the price is \$5 only, not math',
  // Trailing unmatched `\(` with no closing `\)` at all.
  'call f\\(x this is not really latex either',
];

void main() {
  final random = Random(20260926);

  final policies = <String, UnitPolicy Function()>{
    'char-1': () => const CharPolicy(),
    'char-chunk-3': () => const CharPolicy(chunkSize: 3),
    'word': () => const WordPolicy(),
    'atomic': () => const AtomicPolicy(),
  };

  for (final source in _corpus) {
    for (final policyEntry in policies.entries) {
      for (var trial = 0; trial < 8; trial++) {
        test('invariants hold: policy=${policyEntry.key} '
            'source=${_describe(source)} trial=$trial', () {
          _runInvariantCheck(
            source: source,
            policy: policyEntry.value(),
            chunks: _splitAdversarially(source, random),
            useAtomicSpans: true,
          );
        });
      }
    }
  }

  test('final == source and revealed is always a prefix (text mode)', () {
    for (final source in _corpus) {
      for (final policyEntry in policies.entries) {
        var completions = 0;
        final engine = RevealEngine(
          policy: policyEntry.value(),
          atomicSpans: const AtomicSpanDetector(),
          onComplete: () => completions++,
        );
        engine.setSource(source, closed: true);

        double lastProgress = -1;
        var guard = 0;
        while (!engine.isComplete && guard < source.length * 4 + 100) {
          engine.step();
          expect(
            source.startsWith(engine.revealed),
            isTrue,
            reason: 'revealed must be a prefix (policy=${policyEntry.key})',
          );
          expect(engine.progress, greaterThanOrEqualTo(lastProgress));
          lastProgress = engine.progress;
          guard++;
        }
        expect(engine.revealed, source, reason: policyEntry.key);
        expect(engine.isComplete, isTrue, reason: policyEntry.key);
        expect(completions, 1, reason: policyEntry.key);
      }
    }
  });

  test('append after completion never drops characters (W2)', () {
    final engine = RevealEngine(policy: const WordPolicy());
    engine.setSource('Hello there', closed: true);
    engine.revealAll();
    while (!engine.isComplete) {
      engine.step();
    }
    expect(engine.revealed, 'Hello there');

    engine.append(', general kenobi');
    expect(engine.isComplete, isFalse, reason: 're-armed by growth');
    while (engine.cursor < engine.source.length) {
      if (!engine.step()) break;
    }
    engine.close();
    while (!engine.isComplete) {
      if (!engine.step()) break;
    }
    expect(engine.revealed, 'Hello there, general kenobi');
  });

  test('a non-append setSource change keeps the common prefix (W24)', () {
    final engine = RevealEngine(policy: const CharPolicy());
    engine.setSource('The quick brown fox', closed: true);
    for (var i = 0; i < 10; i++) {
      engine.step();
    }
    expect(engine.revealed, 'The quick ');

    // Completely different continuation after the same prefix.
    engine.setSource('The quick red fox jumps', closed: true);
    expect(engine.revealed, 'The quick ', reason: 'prefix must be kept');
    expect(_sourceStartsWith(engine), isTrue);

    while (!engine.isComplete) {
      if (!engine.step()) break;
    }
    expect(engine.revealed, 'The quick red fox jumps');
  });

  test('cursor never lands strictly inside a grapheme cluster', () {
    // Family emoji built from a ZWJ sequence: splitting mid-sequence with
    // char-mode chunking of size 1 must still treat it as one grapheme.
    const family = '👨‍👩‍👧‍👦';
    final engine = RevealEngine(policy: const CharPolicy());
    engine.setSource('a${family}b', closed: true);
    final boundaries = <int>[];
    while (!engine.isComplete) {
      engine.step();
      boundaries.add(engine.cursor);
    }
    for (final b in boundaries) {
      expect(
        _isGraphemeBoundary(engine.source, b),
        isTrue,
        reason: 'cursor=$b must be a grapheme boundary',
      );
    }
    expect(engine.revealed, 'a${family}b');
  });

  test('cursor never lands strictly inside an atomic LaTeX span', () {
    final engine = RevealEngine(
      policy: const CharPolicy(),
      atomicSpans: const AtomicSpanDetector(),
    );
    engine.setSource('before \$x^2+y^2=z^2\$ after', closed: true);
    final spans = const AtomicSpanDetector().spans(engine.source);
    while (!engine.isComplete) {
      engine.step();
      for (final span in spans) {
        expect(span.containsStrictly(engine.cursor), isFalse);
      }
    }
    expect(engine.revealed, engine.source);
  });

  test('a chunk split between a ZWJ and the surrogate half it joins to '
      'never invalidates an already-revealed boundary (regression)', () {
    // Reproduces a real fuzz failure: chunking splits the rainbow flag's
    // surrogate pair right after the preceding ZWJ, so `characters`
    // reports a boundary that later gets swallowed once the pair
    // completes and GB11 pulls it into one cluster.
    const source =
        'team 👨‍👩‍👧‍👦 ready, flags 🏳️‍🌈 🇺🇳 and '
        'plain 😀 emoji';
    const chunks = [
      'team 👨‍👩‍👧‍👦 ready, flags ',
      '🏳️‍🌈',
      ' 🇺🇳 and plain 😀 emoji',
    ];
    final engine = RevealEngine(policy: const CharPolicy());
    for (final chunk in chunks) {
      engine.append(chunk);
      expect(
        _isGraphemeBoundary(engine.source, engine.cursor),
        isTrue,
        reason: 'cursor=${engine.cursor} after appending "$chunk"',
      );
      var guard = 0;
      while (engine.step() && guard < source.length + 10) {
        expect(_isGraphemeBoundary(engine.source, engine.cursor), isTrue);
        guard++;
      }
    }
    engine.close();
    while (!engine.isComplete) {
      if (!engine.step()) break;
    }
    expect(engine.revealed, source);
  });

  test(
    'a lone trailing regional indicator is withheld until its pair '
    'arrives, or a following one, never breaking a flag pair (regression)',
    () {
      // Three flags back-to-back: forces a lone, unpaired regional
      // indicator to sit at the tail of the buffer mid-stream.
      const source = '🇺🇳🇮🇶🇩🇪 done';
      const chunks = ['🇺', '🇳🇮', '🇶🇩', '🇪 done'];
      final engine = RevealEngine(policy: const CharPolicy());
      for (final chunk in chunks) {
        engine.append(chunk);
        expect(_isGraphemeBoundary(engine.source, engine.cursor), isTrue);
        var guard = 0;
        while (engine.step() && guard < source.length + 10) {
          expect(_isGraphemeBoundary(engine.source, engine.cursor), isTrue);
          guard++;
        }
      }
      engine.close();
      while (!engine.isComplete) {
        if (!engine.step()) break;
      }
      expect(engine.revealed, source);
    },
  );

  test('an unmatched \$ in a closed source never stalls completion', () {
    final engine = RevealEngine(
      policy: const CharPolicy(),
      atomicSpans: const AtomicSpanDetector(),
    );
    engine.setSource('the price is \$5 only', closed: true);
    var guard = 0;
    while (!engine.isComplete && guard < 1000) {
      engine.step();
      guard++;
    }
    expect(
      engine.isComplete,
      isTrue,
      reason: 'an unclosed span must stop blocking once input is closed',
    );
    expect(engine.revealed, engine.source);
  });

  test('a currency range in an open stream does not lag the reveal', () {
    // `Plan: $5-10 ...` must be classified as currency, not an unclosed
    // math span: an unclosed span would park the cursor at the `$` for
    // the rest of the stream instead of revealing up to the tail.
    const source = 'Plan: \$5-10 per month billed yearly and more words here';
    const chunks = [
      'Plan: \$5-',
      '10 per month ',
      'billed yearly ',
      'and more words here',
    ];
    final engine = RevealEngine(
      policy: const CharPolicy(),
      atomicSpans: const AtomicSpanDetector(),
    );
    for (final chunk in chunks) {
      engine.append(chunk);
      var guard = 0;
      while (engine.step() && guard < source.length + 10) {
        guard++;
      }
    }
    expect(
      engine.cursor,
      greaterThanOrEqualTo(engine.source.length - 1),
      reason: 'only the final grapheme/word holdback may remain',
    );
  });

  test('an unclosed \$ gives up after 32 units / at end of line while '
      'input is still open', () {
    for (final source in <String>[
      'See \$HOME_DIRECTORY_value and then a long trailing sentence with '
          'many words',
      '\$foo\nnext line',
    ]) {
      final engine = RevealEngine(
        policy: const CharPolicy(),
        atomicSpans: const AtomicSpanDetector(),
      );
      engine.append(source);
      var guard = 0;
      while (engine.step() && guard < source.length + 10) {
        guard++;
      }
      expect(
        engine.cursor,
        greaterThan(source.indexOf('\$')),
        reason: 'reveal must proceed past the \$ in "$source"',
      );
    }
  });

  test(
    'shell \$VARS inside a fenced code block are not atomic spans (W11)',
    () {
      const source = '```bash\necho "\$HOME and \$USER"\n```';
      final spans = const AtomicSpanDetector().spans(source);
      expect(spans, isEmpty);
    },
  );
}

bool _sourceStartsWith(RevealEngine engine) =>
    engine.source.startsWith(engine.revealed);

bool _isGraphemeBoundary(String source, int index) {
  if (index <= 0 || index >= source.length) return true;
  final chars = source.characters;
  var offset = 0;
  for (final g in chars) {
    if (offset == index) return true;
    offset += g.length;
    if (offset > index) return false;
  }
  return offset == index;
}

String _describe(String s) => s.length <= 24 ? s : '${s.substring(0, 21)}...';

/// Splits [source] into random chunks, some of which are deliberately
/// allowed to land mid-surrogate-pair or mid-grapheme-cluster (chunked by
/// raw UTF-16 code unit, not by grapheme), to prove the engine is safe
/// even when a stream delivers text broken at an arbitrary byte offset.
List<String> _splitAdversarially(String source, Random random) {
  if (source.isEmpty) return const [''];
  final cuts = <int>{0, source.length};
  final cutCount = 1 + random.nextInt(6);
  for (var i = 0; i < cutCount; i++) {
    cuts.add(random.nextInt(source.length + 1));
  }
  final sorted = cuts.toList()..sort();
  final chunks = <String>[];
  for (var i = 0; i < sorted.length - 1; i++) {
    chunks.add(source.substring(sorted[i], sorted[i + 1]));
  }
  return chunks;
}

void _runInvariantCheck({
  required String source,
  required UnitPolicy policy,
  required List<String> chunks,
  required bool useAtomicSpans,
}) {
  var completions = 0;
  final engine = RevealEngine(
    policy: policy,
    atomicSpans: useAtomicSpans ? const AtomicSpanDetector() : null,
    onComplete: () => completions++,
  );

  double lastProgress = -1;

  void assertInvariants() {
    expect(
      source.startsWith(engine.revealed),
      isTrue,
      reason: 'revealed "${engine.revealed}" must be a prefix of "$source"',
    );
    expect(engine.cursor >= 0 && engine.cursor <= engine.source.length, isTrue);
    if (engine.source.isNotEmpty) {
      expect(
        _isGraphemeBoundary(engine.source, engine.cursor),
        isTrue,
        reason: 'cursor must sit on a grapheme boundary',
      );
    }
    final spans =
        useAtomicSpans
            ? const AtomicSpanDetector().spans(engine.source)
            : const <AtomicSpan>[];
    for (final span in spans) {
      // An unclosed span (no matching delimiter, e.g. a stray `\(` that
      // never gets a `\)`) only holds the cursor back while more input
      // could still arrive to close it. Once input is closed it never
      // will, so it stops being treated as atomic (see
      // RevealEngine._clampForAtomicSpans) - the engine must still be able
      // to finish revealing that text.
      if (!span.closed && engine.inputClosed) continue;
      expect(span.containsStrictly(engine.cursor), isFalse);
    }
    expect(engine.progress, greaterThanOrEqualTo(lastProgress));
    lastProgress = engine.progress;
  }

  for (final chunk in chunks) {
    engine.append(chunk);
    assertInvariants();
    // Drain whatever is currently revealable before the next chunk
    // arrives, simulating a scheduler ticking between chunks.
    var guard = 0;
    while (engine.step() && guard < source.length + 10) {
      assertInvariants();
      guard++;
    }
  }
  engine.close();

  var guard = 0;
  while (!engine.isComplete && guard < source.length * 2 + 100) {
    engine.step();
    assertInvariants();
    guard++;
  }

  expect(engine.revealed, source, reason: 'final revealed must equal source');
  expect(engine.isComplete, isTrue);
  expect(completions, 1, reason: 'onComplete must fire exactly once');
}
