// Standalone microbenchmark for `mend()` itself (B1-S6 round 10 PERF slice -
// see doc/BENCHMARKS.md's "the real cost is mend()" section and this
// slice's own follow-up section for the numbers this file produces).
//
// Measures two things at 500/5,000/20,000/50,000 characters:
//  * "no state" - `mend()` called once, cold, on a document of that length
//    with no `MendState` at all. This is the pre-existing (and still
//    default) full-scan cost - unchanged by this slice, since a caller that
//    never passes a `MendState` gets the exact same code path as before.
//  * "incremental" - the realistic streaming shape: one shared `MendState`,
//    fed the document ONE CHARACTER AT A TIME from empty up to that length,
//    reporting the cost of the LAST (longest) call only - i.e. the marginal
//    per-call cost once a stream has already reached that length, which is
//    what actually matters for a growing stream's total cost.
//
// Wall-clock, not a correctness test - tagged `benchmark` like
// `stream_benchmark_test.dart`, excluded from the default run:
// `flutter test --no-dds --tags benchmark --run-skipped
// test/perf/mend_microbenchmark_test.dart`.

@Tags(['benchmark'])
library;

import 'package:flutter_streaming_text_markdown/src/render/mend.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a realistic multi-construct markdown document of roughly [length]
/// characters: prose paragraphs, headings, a list, a table, a fenced code
/// block, a link, an image, and `$`-shaped currency/math, repeating as
/// needed to reach the target length, followed by a still-open trailing
/// sentence (the "live tail" every active reveal tick actually has).
String _buildDoc(int length) {
  const block = '''
## Section

Here is some prose that keeps going for a while to pad out the length of
this synthetic document, mentioning a price of \$5-10 per unit along the
way, plus a real inline `codeSpan()` and a [link](https://example.com/x).

1. First step in a short list
2. Second step, a bit longer than the first one
3. Third and final step

| Col A | Col B | Col C |
|-------|-------|-------|
| 1     | 2     | 3     |
| 4     | 5     | 6     |

```dart
void main() {
  print('hello from a fenced code block inside the benchmark doc');
}
```

See ![an image](https://example.com/pic.png) for reference.

''';
  final buffer = StringBuffer();
  while (buffer.length < length) {
    buffer.write(block);
  }
  var doc = buffer.toString();
  if (doc.length > length) doc = doc.substring(0, length);
  return '$doc and the sentence keeps going without a period yet';
}

Duration _timeIt(void Function() body, {int iterations = 50}) {
  // Warm up (JIT, string interning) before the timed loop.
  for (var i = 0; i < 5; i++) {
    body();
  }
  final sw = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    body();
  }
  sw.stop();
  return Duration(microseconds: sw.elapsedMicroseconds ~/ iterations);
}

void main() {
  test('mend() per-call cost: no MendState vs incremental MendState', () {
    final lengths = [500, 5000, 20000, 50000];
    final results = <String>[];
    for (final length in lengths) {
      final doc = _buildDoc(length);

      final noState = _timeIt(() {
        mend(doc, isComplete: false);
      });

      final state = MendState();
      // Prime the cache with every prefix up to (but not including) the
      // final character, so the timed call is the realistic "one more
      // character arrived" marginal cost, not a cold full scan.
      for (var i = 1; i < doc.length; i++) {
        mend(doc.substring(0, i), isComplete: false, state: state);
      }
      final incremental = _timeIt(() {
        mend(doc, isComplete: false, state: state);
      }, iterations: 200);

      final line =
          'length=$length  no-state=${noState.inMicroseconds}us  '
          'incremental=${incremental.inMicroseconds}us  '
          'speedup=${(noState.inMicroseconds / (incremental.inMicroseconds == 0 ? 1 : incremental.inMicroseconds)).toStringAsFixed(1)}x';
      results.add(line);
      // ignore: avoid_print
      print(line);
    }
    // ignore: avoid_print
    print('mend() microbenchmark summary:\n${results.join('\n')}');
  });
}
