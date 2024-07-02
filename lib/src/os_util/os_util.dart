import 'os_util_noop.dart'
    if (dart.library.io) 'os_util_non_web.dart'
    if (dart.library.html) 'os_util_web.dart';

abstract class OSUtil {
  static final OSUtil _instance = getOSUtil();

  static OSUtil get instance {
    return _instance;
  }

  String? getOSName();
}
