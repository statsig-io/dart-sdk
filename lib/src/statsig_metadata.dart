import 'dart:io';

abstract class StatsigMetadata {
  static String? _version;

  static String getSDKVersion() {
    if (_version != null) {
      return _version ?? '';
    }
    var file = File("pubspec.yaml");
    var contents = file.readAsStringSync();
    var lines = contents.split("\n");
    var versionLine =
        lines.firstWhere((element) => element.startsWith("version: "));
    _version = versionLine.substring(("version: ").length);
    return _version ?? '';
  }

  static String getSDKType() {
    return "dart";
  }

  static Map toJson() {
    return {"sdkVersion": getSDKVersion(), "sdkType": getSDKType()};
  }
}
