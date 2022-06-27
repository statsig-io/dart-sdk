class StatsigUser {
  String userId;

  StatsigUser([this.userId = ""]) {}

  Map toJson() => {"userID": userId};
}
