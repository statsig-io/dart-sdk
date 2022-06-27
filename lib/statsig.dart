export 'src/statsig_options.dart' show StatsigOptions;
export 'src/statsig_user.dart' show StatsigUser;

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
  }

  static Future updateUser(StatsigUser user) async {
    await _clientInstance?.updateUser(user);
  }

  static bool checkGate(String gateName, [bool defaultValue = false]) {
    return _clientInstance?.checkGate(gateName) ?? defaultValue;
  }

  static DynamicConfig? getConfig(String configName) {
    return _clientInstance?.getConfig(configName);
  }

  static DynamicConfig? getExperiment(String configName) {
    return _clientInstance?.getConfig(configName);
  }

  static Layer? getLayer(String layerName) {
    return _clientInstance?.getLayer(layerName);
  }

  @visibleForTesting
  static void reset() {
    return _clientInstance = null;
  }
}
