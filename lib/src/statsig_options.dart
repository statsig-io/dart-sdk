class StatsigOptions {
  /// The base url to use for all SDK network requests. Defaults to https://statsigapi.net/v1/
  String? api;

  /// How long (in seconds) the Statsig client waits for the initial network request. Defaults to 3 seconds
  int initTimeout;

  /// Used to signal the environment tier the user is currently in.
  String? environment;

  /// Overrides the auto generated StableID that is set for the device
  String? overrideStableID;

  StatsigOptions(
      {this.api,
      this.initTimeout = 3,
      this.environment,
      this.overrideStableID});
}
