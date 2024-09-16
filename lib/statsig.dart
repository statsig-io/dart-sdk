export 'src/statsig_options.dart' show StatsigOptions, StatsigEnvironment;
export 'src/statsig_user.dart' show StatsigUser;
export 'src/dynamic_config.dart' show DynamicConfig;
export 'src/statsig_layer.dart' show Layer;
export 'src/evaluation_details.dart' show EvaluationDetails;
export 'src/feature_gate.dart' show FeatureGate;

import 'package:meta/meta.dart';
import 'package:statsig/src/parameter_store.dart';
import 'src/dynamic_config.dart';
import 'src/feature_gate.dart';
import 'src/evaluation_details.dart';
import 'src/statsig_client.dart';
import 'src/statsig_layer.dart';
import 'src/statsig_options.dart';
import 'src/statsig_user.dart';

/// The main interface to interact with the Statsig SDK
class Statsig {
  static StatsigClient? _clientInstance;

  /// Initializes the SDK so you can start interacting with Statsig.
  ///
  /// Optionally provide [StatsigUser] and/or [StatsigOptions] to configure the SDK.
  static Future<void> initialize(String sdkKey,
      [StatsigUser? user, StatsigOptions? options]) async {
    _clientInstance =
        await StatsigClient.make(sdkKey, user, options ?? StatsigOptions());
  }

  /// Closes out the SDK flushing any pending events.
  static Future shutdown() async {
    await _clientInstance?.shutdown();
    _clientInstance = null;
  }

  /// Flushes any pending events.
  static Future flush() async {
    await _clientInstance?.flush();
  }

  /// Informs the SDK that the user has changed and that values should be refetched from Statsig.
  static Future updateUser(StatsigUser user) async {
    await _clientInstance?.updateUser(user);
  }

  /// Returns the [FeatureGate] value for the current user.
  static bool checkGate(String gateName, [bool defaultValue = false]) {
    return _clientInstance?.checkGate(gateName, defaultValue) ?? defaultValue;
  }

  static FeatureGate getFeatureGate(String gateName,
      [bool defaultValue = false]) {
    return _clientInstance?.getFeatureGate(gateName, defaultValue) ??
        FeatureGate.empty(gateName, EvaluationDetails.uninitialized());
  }

  /// Returns the [DynamicConfig] with the given configName.
  static DynamicConfig getConfig(String configName) {
    return _clientInstance?.getConfig(configName) ??
        DynamicConfig.empty(configName, EvaluationDetails.uninitialized());
  }

  /// Returns the experiment with the given name as a [DynamicConfig].
  static DynamicConfig getExperiment(String experimentName) {
    return _clientInstance?.getConfig(experimentName) ??
        DynamicConfig.empty(experimentName, EvaluationDetails.uninitialized());
  }

  /// Returns the [Layer] with the given layerName.
  static Layer getLayer(String layerName) {
    return _clientInstance?.getLayer(layerName) ??
        Layer.empty(layerName, EvaluationDetails.uninitialized());
  }

  static ParameterStore getParameterStore(String parameterStoreName) {
    return _clientInstance?.getParameterStore(parameterStoreName) ??
        ParameterStore.empty(
            parameterStoreName, EvaluationDetails.uninitialized());
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
