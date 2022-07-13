class StatsigUser {
  String userId;
  String? email;
  String? ip;
  String? country;
  String? locale;
  String? appVersion;
  Map<String, dynamic>? custom;
  Map<String, String>? customIds;
  Map<String, dynamic>? privateAttributes;

  StatsigUser(
      {this.userId = "",
      this.email = null,
      this.ip = null,
      this.country = null,
      this.locale = null,
      this.appVersion = null,
      this.custom = null,
      this.customIds = null,
      this.privateAttributes = null});

  StatsigUser.fromJson(Map<String, dynamic> json)
      : userId = json["userID"],
        email = json["email"],
        ip = json["ip"],
        country = json["country"],
        locale = json["locale"],
        appVersion = json["appVersion"],
        custom = json["custom"],
        customIds = json["customIDs"],
        privateAttributes = json["privateAttributes"];

  Map toJson() => _toJson();

  Map toPrivacySensitiveJson() => _toJson(true);

  Map _toJson([bool includePrivateAttributes = false]) {
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
          : {})
    };
  }
}
