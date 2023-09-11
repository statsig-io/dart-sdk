import 'dart:convert';
import "package:crypto/crypto.dart";

import 'internal_store.dart';
import 'network_service.dart';
import 'statsig_layer.dart';
import 'statsig_logger.dart';
import 'statsig_metadata.dart';
import 'statsig_options.dart';
import 'statsig_user.dart';
import 'statsig_event.dart';
import 'dynamic_config.dart';

extension NormalizedStatsigUser on StatsigUser {
  StatsigUser normalize(StatsigOptions? options) {
    var json = this.toJsonWithPrivateAttributes();
    if (options != null) {
      json = json..addAll(options.environment?.toJson() ?? {});
    }
    return StatsigUser.fromJson(json);
  }
}

class StatsigClient {
  final String _sdkKey;

  late StatsigUser _user;
  late StatsigOptions _options;
  late NetworkService _network;
  late StatsigLogger _logger;
  late InternalStore _store;

  StatsigClient._make(this._sdkKey,
      [StatsigUser? user, StatsigOptions? options]) {
    _user = user ?? StatsigUser();
    _options = options ?? StatsigOptions();
    _network = NetworkService(_options, _sdkKey);
    _logger = StatsigLogger(_network);
    _store = InternalStore();
  }

  static Future<StatsigClient> make(String sdkKey,
      [StatsigUser? user, StatsigOptions? options]) async {
    await StatsigMetadata.loadStableID(options?.overrideStableID);

    var client = StatsigClient._make(sdkKey, user?.normalize(options), options);
    await client._fetchInitialValues();
    return client;
  }

  Future shutdown() async {
    await _logger.shutdown();
  }

  Future updateUser(StatsigUser user) async {
    await _store.clear();
    _user = user.normalize(this._options);
    StatsigMetadata.regenSessionID();

    await _fetchInitialValues();
  }

  bool checkGate(String gateName, [bool defaultValue = false]) {
    var hash = _getHash(gateName);
    var res = _store.featureGates[hash];
    if (res == null) {
      return defaultValue;
    }

    _logger.enqueue(StatsigEvent.createGateExposure(_user, gateName,
        res["value"], res["rule_id"], res["secondary_exposures"]));

    return res["value"];
  }

  DynamicConfig getConfig(String configName) {
    var hash = _getHash(configName);
    Map? res = _store.dynamicConfigs[hash];
    if (res == null) {
      return DynamicConfig.empty(configName);
    }

    _logger.enqueue(StatsigEvent.createConfigExposure(
        _user, configName, res["rule_id"], res["secondary_exposures"]));

    return DynamicConfig(configName, res["value"]);
  }

  Layer getLayer(String layerName) {
    var hash = _getHash(layerName);
    Map? res = _store.layerConfigs[hash];
    if (res == null) {
      return Layer.empty(layerName);
    }

    String ruleId = res["rule_id"];

    onExposure(Layer layer, String parameterName) {
      var allocatedExperiment = "";
      bool isExplicit =
          (res["explicit_parameters"] ?? []).contains(parameterName);
      List exposures = res["undelegated_secondary_exposures"] ?? [];

      if (isExplicit) {
        allocatedExperiment = res["allocated_experiment_name"];
        exposures = res["secondary_exposures"] ?? [];
      }

      _logger.enqueue(StatsigEvent.createLayerExposure(_user, layerName, ruleId,
          allocatedExperiment, parameterName, isExplicit, exposures));
    }

    return Layer(layerName, res["value"], onExposure);
  }

  void logEvent(String eventName,
      {String? stringValue,
      double? doubleValue,
      Map<String, String>? metadata}) {
    _logger.enqueue(StatsigEvent.createCustomEvent(
        _user, eventName, stringValue, doubleValue, metadata));
    return;
  }

  Future<void> _fetchInitialValues() async {
    await _store.load(_user);
    var res = await _network.initialize(_user, _store);
    if (res is Map) {
      if (res["has_updates"] == true) {
        _store.save(_user, res);
      }
    }
  }

  String _getHash(String input) {
    var bytes = utf8.encode(input);
    var digest = sha256.convert(bytes);
    return base64Encode(digest.bytes);
  }
}
