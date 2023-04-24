class StatsigOptions {
  /// The base url to use for all SDK network requests. Defaults to https://statsigapi.net/v1/
  String? api;

  /// How long (in seconds) the Statsig client waits for the initial network request. Defaults to 3 seconds
  int initTimeout;

  /// Used to signal the environment tier the user is currently in. [production, staging, development]
  StatsigEnvironment? environment;

  /// Overrides the auto generated StableID that is set for the device
  String? overrideStableID;

  StatsigOptions({this.api, this.initTimeout = 3, this.environment, this.overrideStableID});
}

enum StatsigEnvironment {
  development,
  staging,
  production,
}

extension ToJson on StatsigEnvironment {
  Map<String, dynamic> toJson() => <String, dynamic>{
        "statsigEnvironment": <String, String>{
          "tier": this.toString().replaceAll("StatsigEnvironment.", "")
        }
      };
}
