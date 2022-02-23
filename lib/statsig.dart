import 'package:meta/meta.dart';
import 'package:statsig/src/dynamic_config.dart';
import 'package:statsig/src/statsig_client.dart';
import 'package:statsig/src/statsig_options.dart';
import 'package:statsig/src/statsig_user.dart';

class Statsig {
  static StatsigClient? _clientInstance;

  static Future<void> initialize(String sdkKey,
      [StatsigUser? user, StatsigOptions? options]) async {
    _clientInstance = StatsigClient(sdkKey, user, options ?? StatsigOptions());
    return _clientInstance?.fetchInitialValues();
  }

  static bool checkGate(String gateName, [bool defaultValue = false]) {
    return _clientInstance?.checkGate(gateName) ?? defaultValue;
  }

  static DynamicConfig? getConfig(String configName) {
    return _clientInstance?.getConfig(configName);
  }

  @visibleForTesting
  static void reset() {
    return _clientInstance = null;
  }
}
