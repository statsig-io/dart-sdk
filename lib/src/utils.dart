import 'dart:convert';
import 'package:crypto/crypto.dart';

abstract class Utils {
  static String hash(String input) {
    var bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  static String djb2(String input) {
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      int character = input.codeUnitAt(i);
      hash = (hash << 5) - hash + character;
      hash = hash & hash; // Convert to 32bit integer
    }
    return hash.toString();
  }
}
