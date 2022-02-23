import 'dart:convert';
import 'package:crypto/crypto.dart';

abstract class Utils {
  static String hash(String input) {
    var bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }
}
