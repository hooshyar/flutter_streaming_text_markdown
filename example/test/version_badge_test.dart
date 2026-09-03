import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/sections/hero_section.dart';
import 'package:example/version.dart';

void main() {
  // Regression for the 2026-09-03 QA finding: the demo header badge was a
  // hardcoded literal ('v1.9.1') that fell out of sync with every release.
  // `kPackageVersion` is generated from the root pubspec.yaml by
  // tool/generate_version.dart (run before this test in CI); this test
  // guards both that the generation actually matches pubspec.yaml right now
  // and that the badge widget actually renders it.
  test('kPackageVersion matches the root pubspec.yaml version', () {
    final pubspecFile = File('../pubspec.yaml');
    expect(pubspecFile.existsSync(), isTrue,
        reason: 'expected ../pubspec.yaml relative to the example/ package '
            'root — run this test with cwd at example/');

    final versionLine = pubspecFile
        .readAsLinesSync()
        .firstWhere((line) => line.startsWith('version:'));
    final pubspecVersion = versionLine.substring('version:'.length).trim();

    expect(
      kPackageVersion,
      pubspecVersion,
      reason: 'example/lib/version.dart is stale — regenerate it with '
          '`dart run tool/generate_version.dart` from the repo root',
    );
  });

  testWidgets('hero section renders the generated version badge',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HeroSection())),
    );
    await tester.pump();

    expect(find.text('v$kPackageVersion'), findsOneWidget);
  });
}
