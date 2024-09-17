import 'dart:convert';

import 'statsig_user.dart';
import 'evaluation_details.dart';

const internalEventPrefix = "statsig::";
const nonExposedChecksEvent = internalEventPrefix + 'non_exposed_checks';

class StatsigEvent {
  String eventName;
  StatsigUser? user;
  int time = DateTime.now().millisecondsSinceEpoch;
  Map? metadata;
  List<dynamic>? exposures;
  String? stringValue;
  double? doubleValue;

  StatsigEvent._make(this.user, this.eventName,
      {this.metadata, this.exposures, this.stringValue, this.doubleValue});

  StatsigEvent.fromJson(Map<String, dynamic> json)
      : eventName = json["eventName"],
        user = StatsigUser.fromJson(json["user"]),
        time = json["time"],
        exposures = json["secondaryExposures"],
        metadata = json["metadata"],
        doubleValue = json["value"] is String ? null : json["value"],
        stringValue = json["value"] is String ? json["value"] : null;

  Map toJson() {
    var result = {"eventName": eventName, "user": user, "time": time};

    if (exposures != null) {
      result["secondaryExposures"] = exposures ?? [];
    }

    if (metadata != null) {
      result["metadata"] = metadata ?? {};
    }

    if (doubleValue != null || stringValue != null) {
      result["value"] = doubleValue ?? stringValue ?? "";
    }

    return result;
  }

  static StatsigEvent createGateExposure(
      StatsigUser user,
      String gateName,
      bool gateValue,
      String ruleId,
      List<dynamic> exposures,
      EvaluationDetails details) {
    return StatsigEvent._make(user, "statsig::gate_exposure",
        metadata: {
          "gate": gateName,
          "gateValue": gateValue.toString(),
          "ruleID": ruleId,
          "reason": details.reason,
          "lcut": details.lcut.toString(),
          "receivedAt": details.receivedAt.toString()
        },
        exposures: exposures);
  }

  static StatsigEvent createConfigExposure(StatsigUser user, String configName,
      String ruleId, List<dynamic> exposures, EvaluationDetails details) {
    return StatsigEvent._make(user, "statsig::config_exposure",
        metadata: {
          "config": configName,
          "ruleID": ruleId,
          "reason": details.reason,
          "lcut": details.lcut.toString(),
          "receivedAt": details.receivedAt.toString()
        },
        exposures: exposures);
  }

  static StatsigEvent createLayerExposure(
      StatsigUser user,
      String layerName,
      String ruleId,
      String allocatedExperiment,
      String parameterName,
      bool isExplicitParameter,
      List<dynamic> exposures,
      EvaluationDetails details) {
    return StatsigEvent._make(user, "statsig::layer_exposure",
        metadata: {
          "config": layerName,
          "ruleID": ruleId,
          "allocatedExperiment": allocatedExperiment,
          "parameterName": parameterName,
          "isExplicitParameter": isExplicitParameter.toString(),
          "reason": details.reason,
          "lcut": details.lcut.toString(),
          "receivedAt": details.receivedAt.toString()
        },
        exposures: exposures);
  }

  static StatsigEvent createCustomEvent(StatsigUser user, String eventName,
      String? stringValue, double? doubleValue, Map<String, String>? metadata) {
    return StatsigEvent._make(user, eventName,
        stringValue: stringValue, doubleValue: doubleValue, metadata: metadata);
  }

  static StatsigEvent createNonExposedEvent(Map<String, int> nonExposedChecks) {
    return StatsigEvent._make(null, nonExposedChecksEvent,
        metadata: {"checks": json.encode(nonExposedChecks)});
  }
}
