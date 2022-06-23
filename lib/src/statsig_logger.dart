import 'package:statsig/src/network_service.dart';

class StatsigLogger {
  NetworkService _network;

  StatsigLogger(this._network);

  void logGateExposure(String gateName) async {
    _log("statsig::gate_exposure");
  }

  void _log(String eventName) async {
    var arr = [eventName];
    _network.sendEvents(arr);
  }
}
