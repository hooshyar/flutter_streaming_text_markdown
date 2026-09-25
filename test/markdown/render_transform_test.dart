import 'package:flutter_streaming_text_markdown/src/render/render_text_transform.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit coverage for `withholdOpenFence`, the render-only transform moved
/// out of `StreamingText._stableRenderText`. This is a pure function new in
/// this slice, so "fails on main" is: the function/file didn't exist at all
/// on main (38bc831) — importing this path doesn't compile there.
void main() {
  group('withholdOpenFence', () {
    test('is the identity when isComplete is true, fences or not', () {
      const withOpenFence = 'Here:\n```dart\nfinal x = 1;';
      expect(withholdOpenFence(withOpenFence, isComplete: true), withOpenFence);

      const balanced = 'Here:\n```dart\nfinal x = 1;\n```\nDone.';
      expect(withholdOpenFence(balanced, isComplete: true), balanced);
    });

    test('is the identity when fences already balance, even mid-stream', () {
      const balanced = 'Here:\n```dart\nfinal x = 1;\n```\nDone.';
      expect(withholdOpenFence(balanced, isComplete: false), balanced);
    });

    test('is the identity for text with no fences at all', () {
      const plain = 'Just some plain text, no code here.';
      expect(withholdOpenFence(plain, isComplete: false), plain);
    });

    test('withholds a trailing unbalanced fence while incomplete', () {
      const text = 'Here you go:\n```dart\nfinal x = 1;\nfinal y = 2;';
      final result = withholdOpenFence(text, isComplete: false);
      expect(result, 'Here you go:\n');
      expect(result.contains('```'), isFalse);
    });

    test('withholds only the last unbalanced fence, keeping prior complete '
        'blocks intact', () {
      const text = 'A:\n```dart\nfoo();\n```\nB:\n```dart\nbar();';
      final result = withholdOpenFence(text, isComplete: false);
      expect(result, 'A:\n```dart\nfoo();\n```\nB:\n');
    });
  });
}
