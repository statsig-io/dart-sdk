import 'dart:io';
import 'os_util.dart';

OSUtil getOSUtil() => OSUtilNonWeb();

class OSUtilNonWeb extends OSUtil {
  @override
  String? getOSName() {
    switch (Platform.operatingSystem) {
      case "macos":
        return "Mac OS X";
      case "windows":
        return "Windows";
      case "linux":
        return "Linux";
      case "android":
        return "Android";
      case "ios":
        return "iOS";
      default:
        return Platform.operatingSystem;
    }
  }
}
