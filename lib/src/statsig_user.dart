class StatsigUser {
  String userId;

  StatsigUser([this.userId = ""]);

  StatsigUser.fromJson(Map<String, dynamic> json) : userId = json["userID"];

  Map toJson() => {"userID": userId};
}
