import 'os_util.dart';

OSUtil getOSUtil() => OSUtilWeb();

class OSUtilWeb extends OSUtil {
  @override
  String? getOSName() {
    return null;
  }
}
