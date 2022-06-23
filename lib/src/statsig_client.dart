import 'package:statsig/src/network_service.dart';
import 'package:statsig/src/statsig_logger.dart';
import 'package:statsig/src/statsig_options.dart';
import 'package:statsig/src/statsig_user.dart';

import 'dynamic_config.dart';

class StatsigClient {
  String _sdkKey;
  StatsigUser? _user;
  StatsigOptions _options;

  late NetworkService _network;
  late StatsigLogger _logger;

  Map store = new Map();

  StatsigClient(this._sdkKey, this._user, this._options) {
    this._network = NetworkService();
    this._logger = StatsigLogger(_network);
  }

  Future<void> fetchInitialValues() async {
    var res = await _network.initialize();
    store = res;
  }

  bool? checkGate(String gateName) {
    var res = store["feature_gates"]?[gateName];
    _logger.logGateExposure(gateName);
    return res;
  }

  DynamicConfig? getConfig(String configName) {
    Map? config = store["dynamic_configs"]?[configName];
    if (config == null) {
      return DynamicConfig(configName, null);
    }
    return DynamicConfig(configName, config["value"]);
  }
}
