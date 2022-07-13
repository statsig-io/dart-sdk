@Timeout(Duration(seconds: 1))

import 'dart:io';

import 'package:statsig/src/statsig_metadata.dart';
import 'package:test/test.dart';

void main() {
  group('Version Check', () {
    test('version in statsig metadata matches pubspec', () {
      var pubspec = File("pubspec.yaml");
      var contents = pubspec.readAsStringSync();
      var lines = contents.split("\n");
      var versionLine =
          lines.firstWhere((element) => element.startsWith("version: "));
      var version = versionLine.substring(("version: ").length);

      expect(StatsigMetadata.getSDKVersion(), version);
    });
  });
}
