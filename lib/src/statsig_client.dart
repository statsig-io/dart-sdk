import 'dart:convert';
import "package:crypto/crypto.dart";
import 'package:statsig/src/internal_store.dart';

import 'package:statsig/src/network_service.dart';
import 'package:statsig/src/statsig_layer.dart';
import 'package:statsig/src/statsig_logger.dart';
import 'package:statsig/src/statsig_options.dart';
import 'package:statsig/src/statsig_user.dart';
import 'package:statsig/src/statsig_event.dart';

import 'dynamic_config.dart';

class StatsigClient {
  String _sdkKey;

  late StatsigUser _user;
  late StatsigOptions _options;
  late NetworkService _network;
  late StatsigLogger _logger;
  late InternalStore _store;

  StatsigClient(this._sdkKey,
      [StatsigUser? user = null, StatsigOptions? options = null]) {
    this._user = user ?? StatsigUser();
    this._options = options ?? StatsigOptions();
    this._network = NetworkService(this._options);
    this._logger = StatsigLogger(_network);
    this._store = InternalStore();
  }

  Future<void> fetchInitialValues() async {
    var res = await _network.initialize(this._user);
    if (res is Map) {
      _store.save(this._user, res);
    } else {
      await _store.load(this._user);
    }
  }

  Future shutdown() async {
    await _logger.shutdown();
  }

  Future updateUser(StatsigUser user) async {
    await _store.clear();
    _user = user;

    await fetchInitialValues();
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

    Function(Layer, String) onExposure = (layer, parameterName) {
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
    };

    return Layer(layerName, res["value"], onExposure);
  }

  void logEvent(String eventName,
      {String? stringValue = null,
      double? doubleValue = null,
      Map<String, String>? metadata = null}) {
    _logger.enqueue(StatsigEvent.createCustomEvent(
        _user, eventName, stringValue, doubleValue, metadata));
    return;
  }

  String _getHash(String input) {
    var bytes = utf8.encode(input);
    var digest = sha256.convert(bytes);
    return base64Encode(digest.bytes);
  }
}
