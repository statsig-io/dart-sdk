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
    var json = toJsonWithPrivateAttributes();
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

  // Incremented synchronously by every updateUser. In-flight fetches capture
  // the value at their start and re-check it after each await, so a fetch
  // superseded by a newer updateUser stops before mutating the store.
  int _userGeneration = 0;

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
    await client._fetchInitialValues(client._userGeneration);
    return client;
  }

  Future shutdown() async {
    await _logger.shutdown();
  }

  Future flush() async {
    await _logger.flush();
  }

  Future updateUser(StatsigUser user) async {
    var generation = ++_userGeneration;
    // Reset and reload on every updateUser, even for the same user, so the
    // call is always a fresh refetch (matching the other Statsig SDKs) rather
    // than a silent no-op. Marking the store Loading synchronously here means
    // evaluations made before the fetch completes report Loading, never the
    // stale value or Uninitialized.
    _store.clear();
    _store.reason = EvalReason.Loading;
    _logger.clear();
    await _logger.flush();
    if (generation != _userGeneration) {
      // A newer updateUser superseded this one while events were flushing.
      return;
    }
    _user = user.normalize(_options);
    StatsigMetadata.regenSessionID();

    await _fetchInitialValues(generation);
  }

  bool checkGate(String gateName,
      [bool defaultValue = false, bool disableExposureLogging = false]) {
    return getFeatureGate(gateName, defaultValue, disableExposureLogging).value;
  }

  FeatureGate getFeatureGate(String gateName,
      [bool defaultValue = false, bool disableExposureLogging = false]) {
    var res = _store.getFeatureGate(gateName, _getHash(gateName), defaultValue);

    if (disableExposureLogging) {
      _logger.logNonExposureCheck(gateName);
    }

    if (!disableExposureLogging) {
      _logger.logGateExposure(gateName, _user, res.details, res.value,
          res.ruleID, res.secondaryExposures);
    }
    return res;
  }

  DynamicConfig getConfig(String configName,
      {bool disableExposureLogging = false}) {
    var res = _store.getDynamicConfig(configName, _getHash(configName));

    if (disableExposureLogging) {
      _logger.logNonExposureCheck(configName);
    }

    if (!disableExposureLogging) {
      _logger.logConfigExposure(configName, _user, res.details, res);
    }
    return res;
  }

  Layer getLayer(String layerName, {bool disableExposureLogging = false}) {
    onExposure(Layer layer, String parameterName) {
      if (disableExposureLogging) {
        return;
      }
      var allocatedExperiment = "";
      bool isExplicit =
          (layer.explicitParameters ?? []).contains(parameterName);
      List exposures = layer.undelegatedSecondaryExposures;

      if (isExplicit) {
        allocatedExperiment = layer.allocatedExperiment ?? "";
        exposures = layer.secondaryExposures;
      }

      _logger.logLayerExposure(
          layerName,
          _user,
          layer.details,
          layer.ruleID ?? "",
          exposures,
          isExplicit,
          allocatedExperiment,
          parameterName);
    }

    var res = _store.getLayer(layerName, _getHash(layerName), onExposure);
    if (disableExposureLogging) {
      _logger.logNonExposureCheck(layerName);
    }

    return res;
  }

  ParameterStore getParameterStore(
      String parameterStoreName, bool disableExposureLogging) {
    var res = _store.paramStores[parameterStoreName] ??
        _store.paramStores[_getHash(parameterStoreName)];

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

  Future<void> _fetchInitialValues(int generation) async {
    var requestUser = _user;
    var cached = await _store.readCache(requestUser);
    if (generation != _userGeneration) {
      // A newer updateUser cleared the store while the cache was being
      // read; applying this user's values now would contaminate it.
      return;
    }
    _store.applyCache(cached);
    if (_store.reason == EvalReason.Uninitialized ||
        _store.reason == EvalReason.NoValues) {
      _store.reason = EvalReason.Loading;
    }
    var res = await _network.initialize(requestUser, _store);
    if (generation != _userGeneration) {
      // A newer updateUser took over while this request was in flight;
      // discard the response so it can't overwrite the new user's state.
      return;
    }

    if (res is Map) {
      if (res["hashed_sdk_key_used"] != null) {
        if (res["hashed_sdk_key_used"] != Utils.djb2(_sdkKey)) {
          _store.finalize();
          return;
        }
      }
      if (res["has_updates"] == true) {
        _store.save(requestUser, res);
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
