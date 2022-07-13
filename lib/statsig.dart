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

class Statsig {
  static StatsigClient? _clientInstance;

  static Future<void> initialize(String sdkKey,
      [StatsigUser? user, StatsigOptions? options]) async {
    _clientInstance = StatsigClient(sdkKey, user, options ?? StatsigOptions());
    return _clientInstance?.fetchInitialValues();
  }

  static Future shutdown() async {
    await _clientInstance?.shutdown();
    _clientInstance = null;
  }

  static Future updateUser(StatsigUser user) async {
    await _clientInstance?.updateUser(user);
  }

  static bool checkGate(String gateName, [bool defaultValue = false]) {
    return _clientInstance?.checkGate(gateName, defaultValue) ?? defaultValue;
  }

  static DynamicConfig getConfig(String configName) {
    return _clientInstance?.getConfig(configName) ??
        DynamicConfig.empty(configName);
  }

  static DynamicConfig getExperiment(String configName) {
    return _clientInstance?.getConfig(configName) ??
        DynamicConfig.empty(configName);
  }

  static Layer getLayer(String layerName) {
    return _clientInstance?.getLayer(layerName) ?? Layer.empty(layerName);
  }

  static void logEvent(String eventName,
      {String? stringValue = null,
      double? doubleValue = null,
      Map<String, String>? metadata = null}) {
    return _clientInstance?.logEvent(eventName,
        stringValue: stringValue, doubleValue: doubleValue, metadata: metadata);
  }

  @visibleForTesting
  static void reset() {
    return _clientInstance = null;
  }
}
