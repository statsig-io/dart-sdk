import 'dart:convert';

import 'package:statsig/statsig.dart';
import 'package:test/test.dart';

void main() {
  Map<String, dynamic> userMap = {
    "userID": "a_user_id",
    "email": "a@b.cc",
    "ip": "1.2.3.4",
    "country": "nz",
    "locale": "en_US",
    "appVersion": "v1",
    "custom": {
      "a_string": "a",
      "a_number": 1,
      "an_array": [1, "2"],
      "a_dictionary": {"foo": "bar"}
    },
    "customIDs": {"workID": "a_work_id"},
  };
  group('Statsig User', () {
    test('add environment', () {
      var user = StatsigUser.fromJson({
        "userID": "a-user",
        "statsigEnvironment": {"tier": "staging"}
      });
      expect({"tier": "staging"}, user.toJson()["statsigEnvironment"]);
    });

    test('converts to privacy sensitive JSON', () {
      var user = StatsigUser(
          userId: userMap["userID"],
          email: userMap["email"],
          ip: userMap["ip"],
          country: userMap["country"],
          locale: userMap["locale"],
          appVersion: userMap["appVersion"],
          custom: userMap["custom"],
          customIds: userMap["customIDs"],
          privateAttributes: {"should_include": "this"});

      var actual = json.encode(user.toPrivacySensitiveJson());
      var expected = json.encode({
        ...userMap,
        ...{
          "privateAttributes": {"should_include": "this"}
        }
      });

      expect(actual, expected);
    });

    test('converts to JSON without private attributes', () {
      var user = StatsigUser(
          userId: userMap["userID"],
          email: userMap["email"],
          ip: userMap["ip"],
          country: userMap["country"],
          locale: userMap["locale"],
          appVersion: userMap["appVersion"],
          custom: userMap["custom"],
          customIds: userMap["customIDs"],
          privateAttributes: {"should_not_include": "this"});

      var actual = json.encode(user);
      var expected = json.encode(userMap);

      expect(actual, expected);
    });

    test('converts from JSON', () {
      var user = StatsigUser.fromJson(userMap);
      expect(user.userId, userMap["userID"]);
      expect(user.email, userMap["email"]);
      expect(user.ip, userMap["ip"]);
      expect(user.country, userMap["country"]);
      expect(user.locale, userMap["locale"]);
      expect(user.appVersion, userMap["appVersion"]);
      expect(user.custom, userMap["custom"]);
      expect(user.customIds, userMap["customIDs"]);
    });
  });
}
