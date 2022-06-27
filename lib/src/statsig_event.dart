import 'package:statsig/src/statsig_user.dart';

class StatsigEvent {
  String eventName;
  StatsigUser user;
  Map metadata;
  List<dynamic> exposures;

  StatsigEvent._make(
      this.user, this.eventName, this.metadata, this.exposures) {}

  Map toJson() => {
        "eventName": eventName,
        "metadata": metadata,
        "user": user,
        "secondaryExposures": exposures
      };

  static StatsigEvent createGateExposure(StatsigUser user, String gateName,
      bool gateValue, String ruleId, List<dynamic> exposures) {
    return StatsigEvent._make(
        user,
        "statsig::gate_exposure",
        {"gate": gateName, "gateValue": gateValue.toString(), "ruleID": ruleId},
        exposures);
  }

  static StatsigEvent createConfigExposure(StatsigUser user, String configName,
      String ruleId, List<dynamic> exposures) {
    return StatsigEvent._make(user, "statsig::config_exposure",
        {"config": configName, "ruleID": ruleId}, exposures);
  }

  static StatsigEvent createLayerExposure(
      StatsigUser user,
      String layerName,
      String ruleId,
      String allocatedExperiment,
      String parameterName,
      bool isExplicitParameter,
      List<dynamic> exposures) {
    return StatsigEvent._make(
        user,
        "statsig::layer_exposure",
        {
          "config": layerName,
          "ruleID": ruleId,
          "allocatedExperiment": allocatedExperiment,
          "parameterName": parameterName,
          "isExplicitParameter": isExplicitParameter.toString()
        },
        exposures);
  }
}
