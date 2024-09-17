import 'dart:convert';
import "package:crypto/crypto.dart";
import 'package:statsig/src/feature_gate.dart';
import 'package:statsig/src/parameter_store.dart';

import 'utils.dart';
import 'internal_store.dart';
import 'network_service.dart';
import 'statsig_layer.dart';
import 'statsig_logger.dart';
import 'statsig_metadata.dart';
import 'statsig_options.dart';
import 'statsig_user.dart';
import 'statsig_event.dart';
import 'dynamic_config.dart';
import 'evaluation_details.dart';

extension NormalizedStatsigUser on StatsigUser {
  StatsigUser normalize(StatsigOptions? options) {
    var json = this.toJsonWithPrivateAttributes();
    if (options != null) {
      json = json
        ..addAll(options.environment == null
            ? {}
            : {
                "statsigEnvironment": {"tier": options.environment}
              });
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

  Future flush() async {
    await _logger.flush();
  }

  Future updateUser(StatsigUser user) async {
    var isSameUser = user.getCacheKey() == _user.getCacheKey();
    if (!isSameUser) {
      _store.clear();
      _logger.clear();
    }
    _user = user.normalize(_options);
    StatsigMetadata.regenSessionID();

    await _fetchInitialValues(shouldLoadCache: !isSameUser);
  }

  bool checkGate(String gateName,
      [bool defaultValue = false, bool disableExposureLogging = false]) {
    return getFeatureGate(gateName, defaultValue, disableExposureLogging).value;
  }

  FeatureGate getFeatureGate(String gateName,
      [bool defaultValue = false, bool disableExposureLogging = false]) {
    var hash = _getHash(gateName);
    var res = _store.featureGates[hash];

    var details = EvaluationDetails(
        _getFormalEvalReason(_store.reason, EvalStatus.Unrecognized),
        _store.time,
        _store.receivedAt);

    if (disableExposureLogging) {
      _logger.logNonExposureCheck(gateName);
    }

    if (res == null) {
      if (!disableExposureLogging) {
        _logger.logGateExposure(gateName, _user, details, defaultValue, "", []);
      }
      return FeatureGate(gateName, details, defaultValue);
    }

    details.reason = _getFormalEvalReason(_store.reason, EvalStatus.Recognized);
    if (!disableExposureLogging) {
      _logger.logGateExposure(gateName, _user, details, res["value"],
          res["rule_id"], res["secondary_exposures"]);
    }
    return FeatureGate(gateName, details, res["value"]);
  }

  DynamicConfig getConfig(String configName,
      {bool disableExposureLogging = false}) {
    var hash = _getHash(configName);
    Map? res = _store.dynamicConfigs[hash];

    var details = EvaluationDetails(
        _getFormalEvalReason(_store.reason, EvalStatus.Unrecognized),
        _store.time,
        _store.receivedAt);

    if (disableExposureLogging) {
      _logger.logNonExposureCheck(configName);
    }

    if (res == null) {
      if (!disableExposureLogging) {
        _logger.logConfigExposure(configName, _user, details, "", []);
      }

      return DynamicConfig.empty(configName, details);
    }

    details.reason = _getFormalEvalReason(_store.reason, EvalStatus.Recognized);
    if (!disableExposureLogging) {
      _logger.logConfigExposure(configName, _user, details, res["rule_id"],
          res["secondary_exposures"]);
    }

    return DynamicConfig(configName, details, res["value"]);
  }

  Layer getLayer(String layerName, {bool disableExposureLogging = false}) {
    var hash = _getHash(layerName);
    Map? res = _store.layerConfigs[hash];

    var details = EvaluationDetails(
        _getFormalEvalReason(_store.reason, EvalStatus.Unrecognized),
        _store.time,
        _store.receivedAt);
    if (disableExposureLogging) {
      _logger.logNonExposureCheck(layerName);
    }

    if (res == null) {
      return Layer.empty(layerName, details);
    }

    String ruleId = res["rule_id"];
    details.reason = _getFormalEvalReason(_store.reason, EvalStatus.Recognized);

    onExposure(Layer layer, String parameterName) {
      if (disableExposureLogging) {
        return;
      }
      var allocatedExperiment = "";
      bool isExplicit =
          (res["explicit_parameters"] ?? []).contains(parameterName);
      List exposures = res["undelegated_secondary_exposures"] ?? [];

      if (isExplicit) {
        allocatedExperiment = res["allocated_experiment_name"];
        exposures = res["secondary_exposures"] ?? [];
      }

      _logger.logLayerExposure(layerName, _user, details, ruleId, exposures,
          isExplicit, allocatedExperiment, parameterName);
    }

    return Layer(layerName, details, res["value"], onExposure);
  }

  ParameterStore getParameterStore(
      String parameterStoreName, bool disableExposureLogging) {
    var hash = _getHash(parameterStoreName);
    var res =
        _store.paramStores[hash] ?? _store.paramStores[parameterStoreName];

    var details = EvaluationDetails(
        _getFormalEvalReason(_store.reason, EvalStatus.Unrecognized),
        _store.time,
        _store.receivedAt);

    _logger.logNonExposureCheck(parameterStoreName);

    if (res == null) {
      return ParameterStore.empty(parameterStoreName, details);
    }
    return ParameterStore(
        this, parameterStoreName, details, res, disableExposureLogging);
  }

  void logEvent(String eventName,
      {String? stringValue,
      double? doubleValue,
      Map<String, String>? metadata}) {
    _logger.enqueue(StatsigEvent.createCustomEvent(
        _user, eventName, stringValue, doubleValue, metadata));
    return;
  }

  Future<void> _fetchInitialValues({bool shouldLoadCache = true}) async {
    if (shouldLoadCache) {
      await _store.load(_user);
    }
    var res = await _network.initialize(_user, _store);
    if (res is Map) {
      if (res["hashed_sdk_key_used"] != null) {
        if (res["hashed_sdk_key_used"] != Utils.djb2(_sdkKey)) {
          return;
        }
      }
      if (res["has_updates"] == true) {
        _store.save(_user, res);
      } else if (res["has_updates"] == false) {
        _store.reason = EvalReason.NetworkNotModified;
      }
    }

    _store.finalize();
  }

  String _getHash(String input) {
    switch (_store.hashUsed) {
      case "none":
        return input;
      case "djb2":
        return Utils.djb2(input);
      default:
        var bytes = utf8.encode(input);
        var digest = sha256.convert(bytes);
        return base64Encode(digest.bytes);
    }
  }

  String _getFormalEvalReason(EvalReason reason, EvalStatus status) {
    if (reason == EvalReason.Uninitialized || reason == EvalReason.NoValues) {
      return reason.name;
    }

    return reason.name + ":" + status.name;
  }
}
