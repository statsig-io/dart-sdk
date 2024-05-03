import 'dart:convert';

import 'disk_util/disk_util.dart';
import 'statsig_user.dart';

enum EvalReason { NetworkNotModified, Network, Cache, Uninitialized }

enum EvalStatus { Recognized, Unrecognized }

class InternalStore {
  Map featureGates = {};
  Map dynamicConfigs = {};
  Map layerConfigs = {};
  int time = 0;
  int receivedAt = 0;
  Map derivedFields = {};
  String userHash = "";
  String hashUsed = "";
  String reason = EvalReason.Uninitialized.name;

  int getSinceTime(StatsigUser user) {
    if (userHash != user.getFullHash()) {
      return 0;
    }
    return time;
  }

  Map getPreviousDerivedFields(StatsigUser user) {
    if (userHash != user.getFullHash()) {
      return {};
    }
    return derivedFields;
  }

  Future<void> load(StatsigUser user) async {
    var store = await _read(user);
    featureGates = store?["feature_gates"] ?? {};
    dynamicConfigs = store?["dynamic_configs"] ?? {};
    layerConfigs = store?["layer_configs"] ?? {};
    time = store?["time"] ?? 0;
    derivedFields = store?["derived_fields"] ?? {};
    userHash = store?["user_hash"] ?? "";
    hashUsed = store?["hash_used"] ?? "";
    reason = EvalReason.Cache.name;
    receivedAt = store?["receivedAt"] ?? 0;
  }

  Future<void> save(StatsigUser user, Map? response) async {
    featureGates = response?["feature_gates"] ?? {};
    dynamicConfigs = response?["dynamic_configs"] ?? {};
    layerConfigs = response?["layer_configs"] ?? {};
    time = response?["time"] ?? 0;
    derivedFields = response?["derived_fields"] ?? {};
    userHash = user.getFullHash();
    hashUsed = response?["hash_used"] ?? "";
    reason = EvalReason.Network.name;
    receivedAt = DateTime.now().millisecondsSinceEpoch;

    await _write(
        user,
        json.encode({
          "feature_gates": featureGates,
          "dynamic_configs": dynamicConfigs,
          "layer_configs": layerConfigs,
          "time": time,
          "derived_fields": derivedFields,
          "user_hash": userHash,
          "hash_used": hashUsed,
          "receivedAt": receivedAt,
        }));
  }

  Future<void> clear() async {
    featureGates = {};
    dynamicConfigs = {};
    layerConfigs = {};
    time = 0;
    derivedFields = {};
    userHash = "";
    hashUsed = "";
    reason = EvalReason.Uninitialized.name;
    receivedAt = 0;
  }

  Future<void> _write(StatsigUser user, String content) async {
    String key = user.getCacheKey();
    await DiskUtil.instance.write("$key.statsig_store", content);
  }

  Future<Map?> _read(StatsigUser user) async {
    try {
      String key = user.getCacheKey();
      var content = await DiskUtil.instance.read("$key.statsig_store");
      var data = json.decode(content);
      return data is Map ? data : null;
    } catch (_) {}
    return null;
  }
}
