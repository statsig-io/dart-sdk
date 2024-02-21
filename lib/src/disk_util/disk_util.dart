import 'disk_util_noop.dart'
  if (dart.library.io) 'disk_util_non_web.dart'
  if (dart.library.html) 'disk_util_web.dart';

abstract class DiskUtil {
  static DiskUtil _instance = getDiskUtil();

  static DiskUtil get instance {
    if (_instance == null) {
      _instance = getDiskUtil();
    }
    return _instance;
  }

  write(String filename, String contents);
  Future<String> read(String filename,
      {bool destroyAfterReading = false});
}
