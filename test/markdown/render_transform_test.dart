import 'package:flutter_streaming_text_markdown/src/render/mend.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fence-focused regression coverage, adapted from the old
/// `withholdOpenFence` suite (this file's original name) to `mend`
/// (lib/src/render/mend.dart), which replaced it in Phase B1-S1.
///
/// Behaviour changed on purpose: `withholdOpenFence` withheld an entire open
/// fence's content until it closed. `mend` instead passes an already-open
/// fence straight through, so `gpt_markdown` renders it as a growing code
/// block (see `live_code_block_test.dart`) - it only holds back a
/// fence-opener line that hasn't even finished being typed yet (no trailing
/// newline). The full mending surface (marker holding, link/math rewrites,
/// unterminated-inline closing) is covered by `mend_test.dart`.
void main() {
  group('mend (fences)', () {
    test('is the identity when isComplete is true, fences or not', () {
      const withOpenFence = 'Here:\n```dart\nfinal x = 1;';
      expect(mend(withOpenFence, isComplete: true), withOpenFence);

      const balanced = 'Here:\n```dart\nfinal x = 1;\n```\nDone.';
      expect(mend(balanced, isComplete: true), balanced);
    });

    test('is the identity when fences already balance, even mid-stream', () {
      const balanced = 'Here:\n```dart\nfinal x = 1;\n```\nDone.';
      expect(mend(balanced, isComplete: false), balanced);
    });

    test('is the identity for text with no fences at all', () {
      const plain = 'Just some plain text, no code here.';
      expect(mend(plain, isComplete: false), plain);
    });

    test(
      'passes an open fence with a committed opener line straight through',
      () {
        const text = 'Here you go:\n```dart\nfinal x = 1;\nfinal y = 2;';
        expect(mend(text, isComplete: false), text);
      },
    );

    test('passes prior complete fenced blocks through unchanged alongside a '
        'later open one', () {
      const text = 'A:\n```dart\nfoo();\n```\nB:\n```dart\nbar();';
      expect(mend(text, isComplete: false), text);
    });

    test('holds back a fence-opener line that has no trailing newline yet', () {
      const text = 'Here you go:\n``';
      expect(mend(text, isComplete: false), 'Here you go:\n');
    });
  });
}
