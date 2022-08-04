class StatsigOptions {
  /// The base url to use for all SDK network requests. Defaults to https://statsigapi.net/v1/
  String? api;

  /// How long (in seconds) the Statsig client waits for the initial network request. Defaults to 3 seconds
  int initTimeout;

  StatsigEnvironment? environment;

  StatsigOptions({this.api, this.initTimeout = 3, this.environment});
}

enum StatsigEnvironment {
  development,
  staging,
  production,
}

extension ToJson on StatsigEnvironment {
  Map<String, dynamic> toJson() {
    late final String environmentName;
    switch (this) {
      case StatsigEnvironment.development:
        environmentName = 'development';
        break;
      case StatsigEnvironment.staging:
        environmentName = 'staging';
        break;
      case StatsigEnvironment.production:
        environmentName = 'production';
        break;
    }
    return <String, dynamic>{
      "statSigEnvironment": <String, String>{"tier": environmentName}
    };
  }
}
