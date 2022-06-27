import 'dart:convert';
import "package:crypto/crypto.dart";

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

  Map _store = new Map();

  StatsigClient(this._sdkKey,
      [StatsigUser? user = null, StatsigOptions? options = null]) {
    this._user = user ?? StatsigUser();
    this._options = options ?? StatsigOptions();
    this._network = NetworkService(this._options);
    this._logger = StatsigLogger(_network);
  }

  Future<void> fetchInitialValues() async {
    var res = await _network.initialize(this._user);
    _store = res;
  }

  Future shutdown() async {
    await _logger.shutdown();
  }

  Future updateUser(StatsigUser user) async {
    _store = {};
    _user = user;

    fetchInitialValues();
  }

  bool? checkGate(String gateName) {
    var hash = _getHash(gateName);
    var res = _store["feature_gates"]?[hash];
    if (res == null) {
      return false;
    }

    _logger.enqueue(StatsigEvent.createGateExposure(_user, gateName,
        res["value"], res["rule_id"], res["secondary_exposures"]));

    return res["value"];
  }

  DynamicConfig? getConfig(String configName) {
    var hash = _getHash(configName);
    Map? res = _store["dynamic_configs"]?[hash];
    if (res == null) {
      return DynamicConfig(configName, null);
    }

    _logger.enqueue(StatsigEvent.createConfigExposure(
        _user, configName, res["rule_id"], res["secondary_exposures"]));

    return DynamicConfig(configName, res["value"]);
  }

  Layer? getLayer(String layerName) {
    var hash = _getHash(layerName);
    Map? res = _store["layer_configs"]?[hash];
    if (res == null) {
      return Layer(layerName);
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

  String _getHash(String input) {
    var bytes = utf8.encode(input);
    var digest = sha256.convert(bytes);
    return base64Encode(digest.bytes);
  }
}
