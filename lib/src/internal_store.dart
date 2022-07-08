import 'dart:convert';
import 'dart:io';

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
    var userId = user.userId.length > 0 ? user.userId : "STATSIG_NULL_USER";
    var dir = await Directory.systemTemp.create();
    var file = File("${dir.path}/${userId}.statsig_store");
    await file.writeAsString(content);
  }

  Future<Map?> _read(StatsigUser user) async {
    var userId = user.userId.length > 0 ? user.userId : "STATSIG_NULL_USER";
    var exists = await Directory.systemTemp.exists();
    if (!exists) {
      return null;
    }

    var dir = await Directory.systemTemp;
    var file = File("${dir.path}/${userId}.statsig_store");

    if (!(await file.exists())) {
      return null;
    }

    var content = await file.readAsString();
    var data = json.decode(content);
    return data is Map ? data : null;
  }
}
