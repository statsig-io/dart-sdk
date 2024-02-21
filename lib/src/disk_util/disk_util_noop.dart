import 'disk_util.dart';

 DiskUtil getDiskUtil() => DiskUtilNoop();

class DiskUtilNoop extends DiskUtil {
  @override
  write(String filename, String contents) async {
    return;
  }
  @override
  Future<String> read(String filename,
      {bool destroyAfterReading = false}) async {
    return '';
  }
}
