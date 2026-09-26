// Parses coverage/lcov.info (produced by `flutter test --coverage`) and
// exits non-zero if line coverage falls below a threshold. Run from the
// repo root, after generating coverage:
//   flutter test --coverage
//   dart run tool/check_coverage.dart 85
//
// The threshold is a required CLI argument (a percentage, e.g. `85` or
// `85.0`) so this script never silently accepts a stale default the caller
// forgot to update.
import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/check_coverage.dart <min-percent> '
      '[path/to/lcov.info]',
    );
    exit(2);
  }

  final threshold = double.tryParse(args[0]);
  if (threshold == null) {
    stderr.writeln('check_coverage: "${args[0]}" is not a valid percentage.');
    exit(2);
  }

  final lcovPath = args.length > 1 ? args[1] : 'coverage/lcov.info';
  final lcovFile = File(lcovPath);
  if (!lcovFile.existsSync()) {
    stderr.writeln(
      'check_coverage: $lcovPath not found. Run `flutter test --coverage` '
      'first.',
    );
    exit(2);
  }

  var totalLines = 0;
  var hitLines = 0;
  String? currentFile;
  final perFile = <String, ({int total, int hit})>{};

  for (final rawLine in lcovFile.readAsLinesSync()) {
    final line = rawLine.trim();
    if (line.startsWith('SF:')) {
      currentFile = line.substring(3);
    } else if (line.startsWith('DA:')) {
      // DA:<line number>,<execution count>[,<checksum>]
      final parts = line.substring(3).split(',');
      if (parts.length < 2) continue;
      final count = int.tryParse(parts[1]) ?? 0;
      totalLines++;
      if (count > 0) hitLines++;

      if (currentFile != null) {
        final prev = perFile[currentFile] ?? (total: 0, hit: 0);
        perFile[currentFile] = (
          total: prev.total + 1,
          hit: prev.hit + (count > 0 ? 1 : 0),
        );
      }
    } else if (line == 'end_of_record') {
      currentFile = null;
    }
  }

  if (totalLines == 0) {
    stderr.writeln('check_coverage: no coverage data found in $lcovPath.');
    exit(2);
  }

  final percent = hitLines / totalLines * 100;
  stdout.writeln(
    'Coverage: ${percent.toStringAsFixed(2)}% '
    '($hitLines/$totalLines lines) — threshold ${threshold.toStringAsFixed(2)}%',
  );

  if (percent < threshold) {
    stdout.writeln('\nLowest-covered files:');
    final sorted = perFile.entries.toList()
      ..sort((a, b) =>
          (a.value.hit / a.value.total).compareTo(b.value.hit / b.value.total));
    for (final entry in sorted.take(10)) {
      final filePercent = entry.value.hit / entry.value.total * 100;
      stdout.writeln(
        '  ${filePercent.toStringAsFixed(1).padLeft(5)}%  '
        '${entry.value.hit}/${entry.value.total}  ${entry.key}',
      );
    }
    stderr.writeln(
      '\ncheck_coverage: ${percent.toStringAsFixed(2)}% is below the '
      '${threshold.toStringAsFixed(2)}% threshold.',
    );
    exit(1);
  }

  exit(0);
}
