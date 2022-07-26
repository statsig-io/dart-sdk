export 'src/statsig_options.dart' show StatsigOptions;
export 'src/statsig_user.dart' show StatsigUser;
export 'src/dynamic_config.dart' show DynamicConfig;
export 'src/statsig_layer.dart' show Layer;

import 'package:meta/meta.dart';
import 'package:statsig/src/dynamic_config.dart';
import 'package:statsig/src/statsig_client.dart';
import 'package:statsig/src/statsig_layer.dart';
import 'package:statsig/src/statsig_options.dart';
import 'package:statsig/src/statsig_user.dart';

/// The main interface to interact with the Statsig SDK
class Statsig {
  static StatsigClient? _clientInstance;

  /// Initializes the SDK so you can start interacting with Statsig.
  ///
  /// Optionally provide [StatsigUser] and/or [StatsigOptions] to configure the SDK.
  static Future<void> initialize(String sdkKey,
      [StatsigUser? user, StatsigOptions? options]) async {
    _clientInstance = StatsigClient(sdkKey, user, options ?? StatsigOptions());
    return _clientInstance?.fetchInitialValues();
  }

  /// Closes out the SDK flushing any pending events.
  static Future shutdown() async {
    await _clientInstance?.shutdown();
    _clientInstance = null;
  }

  /// Informs the SDK that the user has changed and that values should be refetched from Statsig.
  static Future updateUser(StatsigUser user) async {
    await _clientInstance?.updateUser(user);
  }

  /// Returns the [FeatureGate] value for the current user.
  static bool checkGate(String gateName, [bool defaultValue = false]) {
    return _clientInstance?.checkGate(gateName, defaultValue) ?? defaultValue;
  }

  /// Returns the [DynamicConfig] with the given configName.
  static DynamicConfig getConfig(String configName) {
    return _clientInstance?.getConfig(configName) ??
        DynamicConfig.empty(configName);
  }

  /// Returns the experiment with the given name as a [DynamicConfig].
  static DynamicConfig getExperiment(String experimentName) {
    return _clientInstance?.getConfig(experimentName) ??
        DynamicConfig.empty(experimentName);
  }

  /// Returns the [Layer] with the given layerName.
  static Layer getLayer(String layerName) {
    return _clientInstance?.getLayer(layerName) ?? Layer.empty(layerName);
  }

  /// Logs a custom event to Statsig.
  static void logEvent(String eventName,
      {String? stringValue,
      double? doubleValue,
      Map<String, String>? metadata}) {
    return _clientInstance?.logEvent(eventName,
        stringValue: stringValue, doubleValue: doubleValue, metadata: metadata);
  }

  @visibleForTesting
  static void reset() {
    return _clientInstance = null;
  }
}
