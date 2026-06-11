import 'dart:convert';

import 'disk_util/disk_util.dart';
import 'dynamic_config.dart';
import 'evaluation_details.dart';
import 'feature_gate.dart';
import 'statsig_layer.dart';
import 'statsig_user.dart';

enum EvalReason {
  // ignore: constant_identifier_names
  Loading,
  // ignore: constant_identifier_names
  NetworkNotModified,
  // ignore: constant_identifier_names
  Network,
  // ignore: constant_identifier_names
  Cache,
  // ignore: constant_identifier_names
  Uninitialized,
  // ignore: constant_identifier_names
  NoValues
}

// ignore: constant_identifier_names
enum EvalStatus { Recognized, Unrecognized }

class InternalStore {
  Map featureGates = {};
  Map dynamicConfigs = {};
  Map layerConfigs = {};
  Map paramStores = {};
  int time = 0;
  int receivedAt = 0;
  Map derivedFields = {};
  String userHash = "";
  String hashUsed = "";
  EvalReason reason = EvalReason.Uninitialized;
  String? fullChecksum;
  Map exposures = {};
  Map values = {};

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

  String? getFullChecksum(StatsigUser user) {
    if (userHash != user.getFullHash()) {
      return null;
    }
    return fullChecksum;
  }

  FeatureGate getFeatureGate(
      String name, String hashedName, bool defaultValue) {
    var gate = featureGates[name] ?? featureGates[hashedName];
    if (gate == null) {
      var details = EvaluationDetails(
          _getFormalEvalReason(reason, EvalStatus.Unrecognized),
          time,
          receivedAt);
      return FeatureGate(name, details, defaultValue, "", []);
    }

    var details = EvaluationDetails(
        _getFormalEvalReason(reason, EvalStatus.Recognized), time, receivedAt);
    var secondaryExposures = mapSecondaryExposures(
            gate["s"] == null ? null : List<String>.from(gate["s"])) ??
        gate["secondary_exposures"] ??
        [];
    return FeatureGate(
        name,
        details,
        gate["v"] ?? gate["value"] ?? false,
        gate["r"] ?? gate["rule_id"] ?? "default",
        secondaryExposures,
        gate["i"] ?? gate["id_type"] ?? "");
  }

  DynamicConfig getDynamicConfig(
    String name,
    String hashedName,
  ) {
    var config = dynamicConfigs[name] ?? dynamicConfigs[hashedName];
    if (config == null) {
      var details = EvaluationDetails(
          _getFormalEvalReason(reason, EvalStatus.Unrecognized),
          time,
          receivedAt);
      return DynamicConfig(name, details);
    }

    var details = EvaluationDetails(
        _getFormalEvalReason(reason, EvalStatus.Recognized), time, receivedAt);
    return DynamicConfig(
      name,
      details,
      getValue(config["v"]) ?? config["value"] ?? {},
      config["gn"] ?? config["group_name"],
      mapSecondaryExposures(
              config["s"] == null ? null : List<String>.from(config["s"])) ??
          config["secondary_exposures"] ??
          [],
      config["ea"] ?? config["is_experiment_active"] ?? false,
      config["p"] ?? config["passed"] ?? false,
      config["r"] ?? config["rule_id"] ?? "default",
      config["i"] ?? config["id_type"] ?? "",
    );
  }

  Layer getLayer(
      String name, String hashedName, Function(Layer, String) onExposure) {
    var layer = layerConfigs[name] ?? layerConfigs[hashedName];
    if (layer == null) {
      var details = EvaluationDetails(
          _getFormalEvalReason(reason, EvalStatus.Unrecognized),
          time,
          receivedAt);
      return Layer.empty(name, details);
    }

    var details = EvaluationDetails(
        _getFormalEvalReason(reason, EvalStatus.Recognized), time, receivedAt);
    return Layer(
      name,
      details,
      getValue(layer["v"]) ?? layer["value"] ?? {},
      onExposure,
      layer["r"] ?? layer["rule_id"] ?? "default",
      layer["gn"] ?? layer["group_name"] ?? "",
      mapSecondaryExposures(
              layer["s"] == null ? null : List<String>.from(layer["s"])) ??
          layer["secondary_exposures"] ??
          [],
      mapSecondaryExposures(
              layer["us"] == null ? null : List<String>.from(layer["us"])) ??
          layer["undelegated_secondary_exposures"] ??
          [],
      layer["ae"] ?? layer["allocated_experiment_name"] ?? "",
      layer["ea"] ?? layer["is_experiment_active"] ?? false,
      (layer["ep"] ?? layer["explicit_parameters"] ?? []).cast<String>(),
      layer["pr"] ?? layer["parameter_rule_ids"] ?? {},
      layer["i"] ?? layer["id_type"] ?? "",
    );
  }

  String _getFormalEvalReason(EvalReason reason, EvalStatus status) {
    if (reason == EvalReason.Uninitialized || reason == EvalReason.NoValues) {
      return reason.name;
    }

    return reason.name + ":" + status.name;
  }

  List<dynamic>? mapSecondaryExposures(List<String>? secondaryExposures) {
    if (secondaryExposures == null) {
      return null;
    }
    var mapped = secondaryExposures.map((se) {
      return exposures[se];
    }).toList();
    return mapped;
  }

  Map<String, dynamic>? getValue(String? key) {
    if (key == null) {
      return null;
    }
    return values[key];
  }

  Future<void> load(StatsigUser user) async {
    applyCache(await readCache(user));
  }

  /// Reads a user's persisted values without touching the live store, so the
  /// caller can decide whether the result is still relevant before applying.
  Future<Map?> readCache(StatsigUser user) async {
    return await _read(user);
  }

  void applyCache(Map? store) {
    if (store == null) {
      return;
    }

    featureGates = store["feature_gates"] ?? {};
    dynamicConfigs = store["dynamic_configs"] ?? {};
    layerConfigs = store["layer_configs"] ?? {};
    paramStores = store["param_stores"] ?? {};
    time = store["time"] ?? 0;
    derivedFields = store["derived_fields"] ?? {};
    userHash = store["user_hash"] ?? "";
    hashUsed = store["hash_used"] ?? "";
    receivedAt = store["receivedAt"] ?? 0;
    fullChecksum = store["fullChecksum"];
    exposures = store["exposures"] ?? {};
    values = store["values"] ?? {};
    reason = EvalReason.Cache;
  }

  finalize() {
    if (reason == EvalReason.Loading) {
      reason = EvalReason.NoValues;
    }
  }

  Future<void> save(StatsigUser user, Map? response) async {
    featureGates = response?["feature_gates"] ?? {};
    dynamicConfigs = response?["dynamic_configs"] ?? {};
    layerConfigs = response?["layer_configs"] ?? {};
    paramStores = response?["param_stores"] ?? {};
    time = response?["time"] ?? 0;
    derivedFields = response?["derived_fields"] ?? {};
    userHash = user.getFullHash();
    hashUsed = response?["hash_used"] ?? "";
    reason = EvalReason.Network;
    receivedAt = DateTime.now().millisecondsSinceEpoch;
    fullChecksum = response?["full_checksum"];
    exposures = response?["exposures"] ?? {};
    values = response?["values"] ?? {};

    await _write(
        user,
        json.encode({
          "feature_gates": featureGates,
          "dynamic_configs": dynamicConfigs,
          "layer_configs": layerConfigs,
          "param_stores": paramStores,
          "time": time,
          "derived_fields": derivedFields,
          "user_hash": userHash,
          "hash_used": hashUsed,
          "receivedAt": receivedAt,
          "fullChecksum": fullChecksum,
          "exposures": exposures,
          "values": values,
        }));
  }

  void clear() {
    featureGates = {};
    dynamicConfigs = {};
    layerConfigs = {};
    paramStores = {};
    time = 0;
    derivedFields = {};
    userHash = "";
    hashUsed = "";
    reason = EvalReason.Uninitialized;
    receivedAt = 0;
    fullChecksum = null;
    exposures = {};
    values = {};
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
