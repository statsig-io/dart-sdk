import 'disk_util.dart';
// maintain dart 3.0 compatibility since package:web and package:js are only in dart 3.4
// ignore: deprecated_member_use
import 'dart:html';

DiskUtil getDiskUtil() => DiskUtilWeb();

class DiskUtilWeb extends DiskUtil {
  @override
  write(String filename, String contents) async {
    window.localStorage[filename] = contents;
  }

  @override
  Future<String> read(String filename,
      {bool destroyAfterReading = false}) async {
    var result = window.localStorage[filename] ?? '';
    if (destroyAfterReading) {
      window.localStorage.remove(filename);
    }
    return result;
  }
}
