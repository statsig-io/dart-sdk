import 'os_util.dart';

OSUtil getOSUtil() => OSUtilNoop();

class OSUtilNoop extends OSUtil {
  @override
  String? getOSName() {
    return null;
  }
}
