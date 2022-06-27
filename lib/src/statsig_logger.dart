import 'package:statsig/src/network_service.dart';

class StatsigLogger {
  NetworkService _network;

  StatsigLogger(this._network);

  void logGateExposure(String gateName, Map gateData) async {
    _log("statsig::gate_exposure", {
      "gate": gateName,
      "gateValue": gateData["value"].toString(),
      "ruleID": gateData["rule_id"]
    });
  }

  void _log(String eventName, Map metadata) async {
    var arr = [
      {"eventName": eventName, "metadata": metadata}
    ];
    _network.sendEvents(arr);
  }
}
