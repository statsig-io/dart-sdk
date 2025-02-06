import 'package:uuid/uuid.dart';
import 'disk_util/disk_util.dart';
import 'os_util/os_util.dart';

abstract class StatsigMetadata {
  static String getSDKVersion() {
    return "1.2.4";
  }

  static String getSDKType() {
    return "dart-client";
  }

  static String _sessionId = Uuid().v4();
  static String getSessionID() {
    return _sessionId;
  }

  static void regenSessionID() {
    _sessionId = Uuid().v4();
  }

  static String _stableId = "";
  static String getStableID() {
    if (_stableId.isEmpty) {
      throw Exception("Stable ID has not yet been loaded");
    }
    return _stableId;
  }

  static String? getOSName() {
    return OSUtil.instance.getOSName();
  }

  static Future loadStableID([String? overrideStableID]) async {
    const stableIdFilename = "statsig_stable_id";

    if (overrideStableID != null && overrideStableID.isNotEmpty) {
      _stableId = overrideStableID;
      DiskUtil.instance.write(stableIdFilename, overrideStableID);
      return;
    }

    _stableId = await DiskUtil.instance.read(stableIdFilename);
    if (_stableId.isEmpty) {
      var id = Uuid().v4();
      await DiskUtil.instance.write(stableIdFilename, id);
      _stableId = id;
    }
  }

  static Map toJson() {
    var res = {
      "sdkVersion": getSDKVersion(),
      "sdkType": getSDKType(),
      "sessionID": getSessionID(),
      "stableID": getStableID(),
    };
    var systemName = getOSName();
    if (systemName != null) {
      res["systemName"] = systemName;
    }
    return res;
  }
}
