import 'package:statsig/src/network_service.dart';
import 'package:statsig/src/statsig_options.dart';
import 'package:statsig/src/statsig_user.dart';

import 'dynamic_config.dart';

class StatsigClient {
  String sdkKey;
  StatsigUser? user;
  StatsigOptions options;

  NetworkService network = NetworkService();

  Map store = new Map();

  StatsigClient(this.sdkKey, this.user, this.options);

  Future<void> fetchInitialValues() async {
    var res = await network.initialize();
    store = res;
  }

  bool? checkGate(String gateName) {
    return store["feature_gates"]?[gateName];
  }

  DynamicConfig? getConfig(String configName) {
    Map? config = store["dynamic_configs"]?[configName];
    if (config == null) {
      return DynamicConfig(configName, null);
    }
    return DynamicConfig(configName, config["value"]);
  }
}
