abstract class StatsigMetadata {
  static String getSDKVersion() {
    return "0.1.0";
  }

  static String getSDKType() {
    return "dart";
  }

  static Map toJson() {
    return {"sdkVersion": getSDKVersion(), "sdkType": getSDKType()};
  }
}
