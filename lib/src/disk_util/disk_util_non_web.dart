import 'dart:io';
import 'disk_util.dart';

 DiskUtil getDiskUtil() => DiskUtilNonWeb();

class DiskUtilNonWeb extends DiskUtil {

   @override
  write(String filename, String contents) async {
    var dir = _getTempDir();
    if (!await dir.exists()) {
      await dir.create();
    }

    var file = File("${dir.path}/$filename");
    await file.writeAsString(contents);
  }

  @override
  Future<String> read(String filename,
      {bool destroyAfterReading = false}) async {
    var result = '';
    try {
      var dir = _getTempDir();
      var file = File("${dir.path}/$filename");
      result = await file.readAsString();
      if (destroyAfterReading) {
        await file.delete();
      }
    } catch (_) {}

    return result;
  }

  Directory _getTempDir() {
    return Directory("${Directory.systemTemp.path}/__statsig__");
  }
}
