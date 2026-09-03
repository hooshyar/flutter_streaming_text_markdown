// Regenerates example/lib/version.dart from the root pubspec.yaml's
// `version:` field, so the web demo's version badge can never go stale
// relative to what's actually published. Run from the repo root:
//   dart run tool/generate_version.dart
// CI (.github/workflows/pages.yml) runs this before every web build.
import 'dart:io';

void main() {
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    stderr.writeln('generate_version.dart must be run from the repository root '
        '(pubspec.yaml not found).');
    exit(1);
  }

  final versionLine = pubspecFile
      .readAsLinesSync()
      .firstWhere((line) => line.startsWith('version:'));
  final version = versionLine.substring('version:'.length).trim();

  final outFile = File('example/lib/version.dart');
  outFile.writeAsStringSync('''
// GENERATED FILE — do not edit by hand.
// Regenerate with `dart run tool/generate_version.dart` from the repo root
// (also run automatically by .github/workflows/pages.yml before every
// web build) whenever pubspec.yaml's version changes.

/// The published version of `flutter_streaming_text_markdown`, read from
/// the root `pubspec.yaml` at generation time.
const String kPackageVersion = '$version';
''');

  stdout.writeln('Wrote example/lib/version.dart (kPackageVersion = $version)');
}
