import 'utils.dart';
import 'dart:convert';

class StatsigUser {
  /// A unique identifier for the user.
  String userId;

  /// An email associated with the current user.
  String? email;

  /// The ip address of the requests for the user.
  String? ip;

  /// The country location of the user
  String? country;

  /// The locale for the user
  String? locale;

  /// The current version of the app
  String? appVersion;

  /// Any additional custom user attributes for custom conditions in the console
  ///
  /// NOTE: values other than String, Double, Boolean, Array<String>
  ///       will be dropped from the map
  Map<String, dynamic>? custom;

  /// The custom identifiers associated with this user.
  ///
  /// The Key of each entry is the identifiers name and the Value is the identifiers value.
  Map<String, String>? customIds;

  /// Any user attributes that should be used in evaluation only and removed in any logs.
  Map<String, dynamic>? privateAttributes;

  Map<String, dynamic>? _statsigEnvironment;

  StatsigUser(
      {this.userId = "",
      this.email,
      this.ip,
      this.country,
      this.locale,
      this.appVersion,
      this.custom,
      this.customIds,
      this.privateAttributes});

  StatsigUser.fromJson(Map<String, dynamic> json)
      : userId = json["userID"],
        email = json["email"],
        ip = json["ip"],
        country = json["country"],
        locale = json["locale"],
        appVersion = json["appVersion"],
        custom = json["custom"],
        customIds = json["customIDs"],
        privateAttributes = json["privateAttributes"],
        _statsigEnvironment = json["statsigEnvironment"];

  Map<String, dynamic> toJson() => _toJson();

  Map<String, dynamic> toJsonWithPrivateAttributes() => _toJson(true);

  Map<String, dynamic> _toJson([bool includePrivateAttributes = false]) {
    return {
      "userID": userId,
      "email": email,
      "ip": ip,
      "country": country,
      "locale": locale,
      "appVersion": appVersion,
      "custom": custom,
      "customIDs": customIds,
      ...(includePrivateAttributes
          ? {"privateAttributes": privateAttributes}
          : {}),
      ...(_statsigEnvironment != null
          ? {"statsigEnvironment": _statsigEnvironment}
          : {})
    };
  }

  String getFullHash() {
    return Utils.djb2(json.encode(toJsonWithPrivateAttributes()));
  }
}
