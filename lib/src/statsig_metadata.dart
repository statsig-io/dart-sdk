import 'package:uuid/uuid.dart';
import 'disk_util.dart';

abstract class StatsigMetadata {
  static String getSDKVersion() {
    return "0.6.0";
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

  static Future loadStableID([String? overrideStableID]) async {
    const stableIdFilename = "statsig_stable_id";

    if (overrideStableID != null && overrideStableID.isNotEmpty) {
      _stableId = overrideStableID;
      DiskUtil.write(stableIdFilename, overrideStableID);
      return;
    }

    _stableId = await DiskUtil.read(stableIdFilename);
    if (_stableId.isEmpty) {
      var id = Uuid().v4();
      await DiskUtil.write(stableIdFilename, id);
      _stableId = id;
    }
  }

  static Map toJson() {
    return {
      "sdkVersion": getSDKVersion(),
      "sdkType": getSDKType(),
      "sessionID": getSessionID(),
      "stableID": getStableID()
    };
  }
}
