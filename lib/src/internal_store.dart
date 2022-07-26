import 'dart:convert';

import 'package:statsig/src/disk_util.dart';
import 'package:statsig/statsig.dart';

class InternalStore {
  Map featureGates = {};
  Map dynamicConfigs = {};
  Map layerConfigs = {};

  Future<void> load(StatsigUser user) async {
    var store = await _read(user);
    save(user, store);
  }

  Future<void> save(StatsigUser user, Map? response) async {
    featureGates = response?["feature_gates"] ?? {};
    dynamicConfigs = response?["dynamic_configs"] ?? {};
    layerConfigs = response?["layer_configs"] ?? {};

    await _write(
        user,
        json.encode({
          "feature_gates": featureGates,
          "dynamic_configs": dynamicConfigs,
          "layer_configs": layerConfigs,
        }));
  }

  Future<void> clear() async {
    featureGates = {};
    dynamicConfigs = {};
    layerConfigs = {};
  }

  Future<void> _write(StatsigUser user, String content) async {
    var userId = user.userId.isNotEmpty ? user.userId : "STATSIG_NULL_USER";
    await DiskUtil.write("$userId.statsig_store", content);
  }

  Future<Map?> _read(StatsigUser user) async {
    try {
      var userId = user.userId.isNotEmpty ? user.userId : "STATSIG_NULL_USER";
      var content = await DiskUtil.read("$userId.statsig_store");
      var data = json.decode(content);
      return data is Map ? data : null;
    } catch (_) {}
    return null;
  }
}
