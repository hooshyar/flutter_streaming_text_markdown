// Safety net for `MendState` (B1-S6 round 10 PERF slice - see
// doc/BENCHMARKS.md's "the real cost is mend()" and the follow-up perf
// slice's own section).
//
// `mend()` with a `MendState` resumes several internal scans from a
// checkpoint instead of re-walking the whole body every call, purely for
// speed - it must never change WHAT `mend()` returns. This file is the
// actual proof of that: for every document in a wide corpus (every probe12
// case, the full B1F1 identity matrix, a sweep of every construct earlier
// rounds fixed a bug in - lists, tables, links, images, thematic breaks,
// fences - and several long, realistic multi-construct LLM-style answers),
// for both `isComplete` values and both `latexEnabled` values, the
// incremental result (`mend(prefix, state: sharedState)`) must equal the
// full-scan result (`mend(prefix)`, no state at all - the untouched,
// original code path) BYTE FOR BYTE:
//   * walking every prefix in increasing order, one `MendState` reused
//     across the whole walk (the actual streaming shape);
//   * walking prefixes of the SAME document in random order, one shared
//     `MendState` (exercises the non-append/"jump backwards" fallback);
//   * jumping between prefixes of DIFFERENT documents on one shared
//     `MendState` (exercises the "totally different document" fallback,
//     and that a stale cache from one document never leaks into another).
//
// A failure here means `MendState` diverged from `mend()`'s ground truth -
// treat it as a correctness bug in the incremental scanners
// (`_CodeContextScan`/`_LinkHoldScan`/`_SplitScan` in mend.dart), not a
// flaky test.

import 'dart:math';

import 'package:flutter_streaming_text_markdown/src/render/mend.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Corpus
// ---------------------------------------------------------------------------

// The 26 probe12 cases, verbatim (same values as
// test/markdown/mend_widget_test.dart's `_probe12Cases` /
// test/markdown/mend_test.dart's identity corpus).
const _probe12 = <String>[
  'This is **very imp',
  'This is *emph',
  'Mixed ***str',
  'Old ~~price',
  'Call `fooBar(',
  'See [the docs',
  'See [the docs](https://exa',
  'Pic ![alt](https://x.y/a.pn',
  '| Name | Age |',
  '| Name | Age |\n|---',
  '| Name | Age |\n|---|---|\n| Bob | 4',
  'Steps:\n\n1.',
  'Steps:\n\n-',
  '- a\n  - b\n    -',
  'Intro\n\n##',
  'Intro\n\n## Setu',
  'Code:\n\n```dart\nvoid main() {',
  'Code:\n\n``',
  r'Energy $E = mc^',
  'Formula:\n\n\$\$\\frac{a}{',
  r'Energy \(E = mc^',
  'Line<br',
  'Text <span style="color:red">red',
  'Quote:\n\n>',
  'Above\n\n--',
  r'Price 5\*',
];

// The B1F1 identity-matrix corpus's extra shapes (test/markdown/
// mend_test.dart's `corpus` map, non-probe12 entries).
const _identityMatrixExtras = <String>[
  'Title\n--\n\nBody',
  'Title\n==\n\nBody',
  'Mixed ***strong italic*** done',
  'This is __bold__ text',
  'snake_case_name stays literal',
  '* first\n* second\n* third',
  r'5\*3=15, not math',
  'Line one\r\nLine two\r\n\r\nLine three',
  r'Prices: $5-10, $5bn, and $5–10 too.',
  r'**$20** off today',
  'Just a normal finished paragraph.',
  'Code:\n\n```dart\nvoid main() {}\n```\nDone.',
  r'Formula: $$\frac{a}{b}$$ done.',
];

// A sweep of every construct a B1F1 round fixed a bug in (see
// test/markdown/mend_test.dart and inline_marker_streaming_test.dart for
// the full history) - lists, tables, links, images, thematic breaks,
// currency, math.
const _mendSweep = <String>[
  'Hello **bold*',
  'a ~~gone~',
  'Use snake_case and _private names in this module always. ',
  'Use a*b + c for the sum and then we are done. ',
  'Compute 2 * 3 = 6 and then 4 * 5 = 20, done. ',
  'Hello __bold_ and more text keeps going here. ',
  '| Name | Age\n|---|---|\n| Bob | 42 |\n\nDone with it. ',
  'See [docs] for more information right now please. ',
  'Great deal! Check ![alt text](https://x.y/a.png) image below. ',
  'Steps:\n\n12 apples were bought at the store today. ',
  'price ~5 or so, thanks for asking about it today. ',
  'Use `vec![1, 2, 3]` to build a vector quickly here. ',
  'Code:\n\n```dart\nvoid main() {\n  print(1);\n}\n```\nAfter. ',
  'Steps:\n\n- one\n- two\n- three\n\nDone with the list. ',
  'Steps:\n\n1. one\n2. two\n3. three\n\nDone with the list. ',
  '- a\n  - nested one\n  - nested two\n- b\n\nDone with it. ',
  'A.\n\n***\n\nFinal words after the break. ',
  'A.\n\n---\n\nFinal words after the break. ',
  'A.\n\n___\n\nFinal words after the break. ',
  'A.\n\n* * *\n\nFinal words after the break. ',
  'Here:\n\n| Name |',
  'Here:\n\n| Name | Age |\n|---',
  '- one\n- two\n\n| Name | Age |\n|---|---|\n\nDone. ',
  '## Section\n\n| Name | Age |\n|---|---|\n\nDone. ',
  r'The variable $count holds the total and $name the label for this row. ',
  r'It costs **$20** or _$5_ or $5bn or $5–10 per month, fine. ',
  'Price 5\\* and more text follows right after it. ',
];

/// A handful of long, realistic multi-construct LLM-style answers: prose,
/// headings, lists (flat and nested), a table, fenced code, inline code,
/// links, an image, LaTeX-shaped `$`, currency, and a thematic break - the
/// exact mix `mend`'s callers stream through in production.
final _longRealisticAnswers = <String>[
  '''
## Summary

Here's how to solve the problem, step by step.

1. First, install the dependency: `npm install left-pad`.
2. Then import it in your entry point.
3. Finally, call it with the string and the target width.

### Example

```javascript
const leftPad = require('left-pad');

function formatId(id) {
  return leftPad(id, 8, '0');
}

console.log(formatId(42)); // 00000042
```

Note the cost is O(n) where n is the padding width, not the input length.
If \$n\$ is large this can matter, but for typical IDs (n <= 12) it never
does in practice - the currency example \$5-10 per unit is unrelated to
this \$n\$ variable, just a coincidence in symbol choice.

### Comparison

| Approach   | Time  | Space | Notes                        |
|------------|-------|-------|-------------------------------|
| left-pad   | O(n)  | O(n)  | simplest, well-tested         |
| Array.fill | O(n)  | O(n)  | no dependency needed          |
| sprintf    | O(n)  | O(n)  | pulls in a much bigger package|

See [the left-pad incident](https://en.wikipedia.org/wiki/Npm) for why this
tiny package matters more than its size suggests, and check out
![a diagram of the dependency graph](https://example.com/graph.png) for the
full picture.

- Left-pad is small
- Left-pad is everywhere
  - Even in some CI pipelines
  - Even in some build tools
- Left-pad broke the internet once

---

That's the whole story. Questions welcome.
''',
  '''
# Refactoring plan

We're going to split `UserService` into three collaborators:

* `UserRepository` - persistence only, no business rules
* `UserValidator` - pure functions, easy to unit test
* `UserNotifier` - side effects (email, push), isolated so tests can mock it

## Why

The current class mixes all three concerns, so `it('creates a user')` tests
end up asserting on database rows AND email sends AND push payloads in one
120-line test. That's `\$O(n^2)\$` maintenance cost as we add more user
actions - every new action multiplies the assertions in every existing test
that happens to touch users.

## Migration steps

1. Extract `UserValidator` first (pure functions, zero risk).
2. Extract `UserNotifier` second, behind an interface so we can swap in a
   `NoopNotifier` for tests.
3. Extract `UserRepository` last, once the other two are stable.

```python
class UserValidator:
    def validate(self, user: dict) -> list[str]:
        errors = []
        if not user.get("email"):
            errors.append("email required")
        if "@" not in user.get("email", ""):
            errors.append("email invalid")
        return errors
```

Once this lands, `___STATUS___` markers in the ticket tracker should flip
from `in-progress` to `done` for tickets #4021-#4028.

| Ticket | Owner | Status      |
|--------|-------|-------------|
| #4021  | asha  | in-progress |
| #4022  | asha  | not-started |
| #4023  | mo    | in-progress |

Ping #eng-platform if you want to pair on any of this.
''',
  '''
Sure, here's a quick overview of the pricing.

The base plan costs \$5 per seat per month, or \$50 per seat per year (a
\$5-10 savings depending on how you count the free trial month). The
enterprise plan is priced per conversation instead: \$0.002 per message,
with volume discounts starting at 1M messages/month.

**Included in every plan:**

1. Unlimited workspaces
2. SSO via SAML
3. Audit logs (90 day retention)

**Add-ons:**

- Extended retention (\$20/mo per extra year)
- Priority support (\$99/mo)
- Custom domains (\$15/mo)

For the exact formula, see \$total = base + (extra\\_seats \\times 5)\$ - note
this is a rough estimate and doesn't include tax.

```bash
curl -X POST https://api.example.com/v1/quote \\
  -H "Authorization: Bearer \$TOKEN" \\
  -d '{"seats": 12, "plan": "enterprise"}'
```

Check the [pricing page](https://example.com/pricing) for the live
calculator, or reach out and we'll run the numbers together.

* * *

Let me know if you'd like a formal quote.
''',
];

// Round-10 verify blocking item: `_LinkHoldScan`'s "no match"/"trailing `!`"
// branches used to resume from `s.length`/`s.length - 1` - PAST an earlier,
// still-open `[`/`![` that has no closing `]` yet. Since neither pattern can
// match until that `]` arrives, every call while it's still open falls into
// one of those two branches and keeps bumping the resume point forward with
// the string, so by the time the closing `]` finally lands, the resume point
// sits AFTER the `[` that must anchor the match - the incremental scan misses
// it entirely where a full scan would not. Fixed by resuming from one char
// before the last `]` already in the string (or 0 with none) instead -
// see `_LinkHoldScan._lowerBoundBeforeLastClose` in mend.dart.
const _linkHoldAdversarial = <String>[
  // The minimal case that actually diverges: a bare (non-`!`) open bracket
  // whose content spans multiple committed (blank-line-separated) lines
  // before it closes - long enough, and with committed blank lines inside
  // the wrongly-unheld span, that a wrong (untruncated) `linkSafeBody` moves
  // `settledSplitOffset`'s split point and leaks raw `[...]` text into the
  // "settled" prefix that a correct scan would have held back entirely.
  'Intro para.\n\n'
      '[bracket text\n\n'
      'more stuff\n\n'
      'final].\n\n'
      'After paragraph continues typing for a while to move the split '
      'forward and reveal what happened before it settled down nicely '
      'here at last so this becomes long enough to matter for the test.',
  // A lone trailing `!` later followed by both a bare `[x]` and a `![y](`.
  'Wow! Anyway check out [x] and also ![y](https://a.b/c.png) done with '
      'this sentence, then a whole extra paragraph follows.\n\n'
      'Second paragraph keeps going long enough to move the split forward '
      'and expose anything the first paragraph left unheld.',
  // Nested brackets: the outer pair's content contains another full
  // `[...]` pair, which `_closedBracketNoParenYet`'s `[^\[\]]*` cannot see
  // through, so a naive resume point could sit inside the nesting.
  'Data [outer [inner] tail] more text after that continues on for a '
      'while so the paragraph fully commits.\n\n'
      'Next paragraph long enough to push the split point forward past '
      'the first one and reveal any leftover raw brackets.',
  // Brackets that are only ever inside a code span - never real markdown
  // link syntax at all - interleaved with a real link, exercising the
  // `_isInsideCodeContext` gate alongside `_LinkHoldScan`.
  'Use `arr[i][j]` for indexing and later mention [real link](https://'
      'example.com) for context, then keep writing more sentences here.\n\n'
      'A second paragraph long enough to commit the first one and check '
      'nothing about the code span leaked through incorrectly.',
  // A fence that closes and reopens, with an unresolved bracket sitting in
  // the plain-text gap between the two fences.
  '```\ncode one\n```\n\n'
      'Between fences: [gap bracket still open here for a while) done.\n\n'
      '```\ncode two\n```\n\n'
      'Trailing paragraph long enough to move the split forward again.',
  // `~~~` fences (not just ``` ) around an unresolved bracket.
  '~~~\ntilde fence content\n~~~\n\n'
      'After the tilde fence: [another still-open bracket for a while) ok.'
      '\n\nMore trailing text so the paragraph above fully settles.',
  // CRLF line endings throughout, including inside the unresolved bracket
  // span itself.
  'Line one\r\n\r\n'
      '[bracket\r\ncontinued\r\n\r\nclosed] tail\r\n\r\n'
      'More text after crlf blank lines keeps going for a while so this '
      'becomes long enough to matter for the split point.',
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

void _expectSameForBothModes(
  String prefix, {
  required MendState state,
  required String context,
}) {
  for (final isComplete in [false, true]) {
    for (final latexEnabled in [false, true]) {
      final full = mend(
        prefix,
        isComplete: isComplete,
        latexEnabled: latexEnabled,
      );
      final incremental = mend(
        prefix,
        isComplete: isComplete,
        latexEnabled: latexEnabled,
        state: state,
      );
      expect(
        incremental,
        full,
        reason:
            '$context: mismatch at isComplete=$isComplete '
            'latexEnabled=$latexEnabled for prefix length '
            '${prefix.length}: "$prefix"',
      );
    }
  }
}

/// Walks [doc] as a realistic single stream would: EVERY prefix call uses
/// `isComplete: false` (matching real streaming - a caller only ever flips
/// `isComplete` once, at the very end, not on every chunk) against the SAME
/// [state], comparing each step against the full-scan `mend()` with no
/// state at all.
///
/// Deliberately NOT built on [_expectSameForBothModes]: that helper probes
/// `isComplete: true` on the SAME shared `state` at every single step, and
/// `mend` unconditionally calls `state?.reset()` whenever `isComplete` is
/// true - so a walk built on it resets `state`'s checkpoints back to empty
/// after every single prefix, before the next prefix's call ever runs. That
/// makes every step an effective full re-scan and structurally CANNOT
/// exercise (or catch a bug in) multi-step resumption - exactly the bug
/// class `_LinkHoldScan`'s round-10 resume bug belongs to. This helper is
/// the actual reproduction shape for that class of bug.
void _expectRealisticAppendOnlyStream(String doc, {required String context}) {
  final state = MendState();
  for (var i = 1; i <= doc.length; i++) {
    final prefix = doc.substring(0, i);
    final full = mend(prefix, isComplete: false);
    final incremental = mend(prefix, isComplete: false, state: state);
    expect(
      incremental,
      full,
      reason: '$context: mismatch at prefix length $i: "$prefix"',
    );
  }
}

void main() {
  final corpus = [
    ..._probe12,
    ..._identityMatrixExtras,
    ..._mendSweep,
    ..._longRealisticAnswers,
    ..._linkHoldAdversarial,
  ];

  group('MendState: in-order prefix walk matches full-scan mend()', () {
    for (var docIndex = 0; docIndex < corpus.length; docIndex++) {
      final doc = corpus[docIndex];
      test('document #$docIndex (length ${doc.length})', () {
        final state = MendState();
        for (var i = 1; i <= doc.length; i++) {
          _expectSameForBothModes(
            doc.substring(0, i),
            state: state,
            context: 'doc #$docIndex in-order',
          );
        }
      });
    }
  });

  group('MendState: random-order prefix walk (non-append fallback) matches '
      'full-scan mend()', () {
    for (var docIndex = 0; docIndex < corpus.length; docIndex++) {
      final doc = corpus[docIndex];
      if (doc.length < 2) continue;
      test('document #$docIndex (length ${doc.length})', () {
        final random = Random(1000 + docIndex);
        final lengths = List<int>.generate(doc.length, (i) => i + 1)
          ..shuffle(random);
        final state = MendState();
        for (final len in lengths) {
          _expectSameForBothModes(
            doc.substring(0, len),
            state: state,
            context: 'doc #$docIndex random-order',
          );
        }
      });
    }
  });

  test('MendState: jumping between different documents never leaks state '
      'across them', () {
    final state = MendState();
    final random = Random(42);
    for (var round = 0; round < 200; round++) {
      final doc = corpus[random.nextInt(corpus.length)];
      final len = 1 + random.nextInt(doc.length);
      _expectSameForBothModes(
        doc.substring(0, len),
        state: state,
        context: 'cross-document jump round $round',
      );
    }
  });

  test('MendState: a non-prefix edit (same length prefix, different content) '
      'falls back correctly', () {
    final state = MendState();
    const a = 'Steps:\n\n- one\n- two\n- three\n\nDone with the list. ';
    const b = 'Steps:\n\n1. one\n2. two\n3. three\n\nDone with the list. ';
    for (var i = 1; i <= a.length && i <= b.length; i++) {
      _expectSameForBothModes(
        a.substring(0, i),
        state: state,
        context: 'edit-fallback a@$i',
      );
      _expectSameForBothModes(
        b.substring(0, i),
        state: state,
        context: 'edit-fallback b@$i',
      );
    }
  });

  test('MendState: reset() forces a full scan on the next call', () {
    final state = MendState();
    const doc = '| Name | Age |\n|---|---|\n| Bob | 42 |\n\nDone. ';
    for (var i = 1; i <= doc.length; i++) {
      mend(doc.substring(0, i), isComplete: false, state: state);
    }
    state.reset();
    _expectSameForBothModes(doc, state: state, context: 'post-reset');
  });

  test('MendState: _LinkHoldScan resume bug - a bare open bracket spanning '
      'committed blank lines is not missed once it closes (round 10 '
      'regression)', () {
    // Minimal reproduction: walking this document char-by-char through a
    // fresh MendState, using ONLY isComplete:false (the realistic
    // streaming shape - see `_expectRealisticAppendOnlyStream`'s doc
    // comment for why this must NOT go through `_expectSameForBothModes`),
    // used to diverge from the full-scan mend() the instant the closing
    // `]` landed, because `_LinkHoldScan`'s resume point had already been
    // bumped past the opening `[` by the intervening no-match calls.
    const doc = 'Intro para.\n\n[bracket text\n\nmore stuff\n\nfinal].';
    _expectRealisticAppendOnlyStream(doc, context: 'linkhold-resume-bug');
  });

  group('MendState: realistic append-only single stream (isComplete:false '
      'throughout) matches full-scan mend() - the actual reproduction shape '
      'for multi-step resumption bugs', () {
    for (var docIndex = 0; docIndex < corpus.length; docIndex++) {
      final doc = corpus[docIndex];
      test('document #$docIndex (length ${doc.length})', () {
        _expectRealisticAppendOnlyStream(
          doc,
          context: 'doc #$docIndex realistic-stream',
        );
      });
    }
  });

  test('MendState: a non-prefix edit specifically inside an unresolved link '
      'hold falls back correctly', () {
    final state = MendState();
    const a = 'See [first draft link text here for a while longer.';
    const b = 'See [totally different draft text instead for a while.';
    for (var i = 1; i <= a.length && i <= b.length; i++) {
      final prefixA = a.substring(0, i);
      expect(
        mend(prefixA, isComplete: false, state: state),
        mend(prefixA, isComplete: false),
        reason: 'linkhold-edit-fallback a@$i',
      );
      final prefixB = b.substring(0, i);
      expect(
        mend(prefixB, isComplete: false, state: state),
        mend(prefixB, isComplete: false),
        reason: 'linkhold-edit-fallback b@$i',
      );
    }
  });

  test('MendState: reused across two different documents falls back instead '
      'of leaking link-hold state from one into the other', () {
    final state = MendState();
    const docA = 'First document.\n\n[a bracket left open here for a while).';
    const docB =
        'Completely different second document.\n\n'
        '![an image alt left open here](https://example.com/pic.png) '
        'with more text following it for good measure.';
    for (var i = 1; i <= docA.length; i++) {
      mend(docA.substring(0, i), isComplete: false, state: state);
    }
    // Switching documents on the SAME state instance without calling
    // reset() is exactly the "never share across unrelated documents"
    // misuse MendState's own doc comment warns against - `mend` itself
    // must still fall back safely (via the shorter-body/non-prefix
    // check) rather than silently reusing docA's stale checkpoints.
    for (var i = 1; i <= docB.length; i++) {
      final prefix = docB.substring(0, i);
      expect(
        mend(prefix, isComplete: false, state: state),
        mend(prefix, isComplete: false),
        reason: 'cross-doc-reuse-no-reset@$i',
      );
    }
  });
}
