import 'dart:async';

import 'package:statsig/src/network_service.dart';
import 'package:statsig/src/statsig_event.dart';

const maxQueueLength = 100;
const loggingIntervalMillis = 10000;

class StatsigLogger {
  NetworkService _network;
  List<StatsigEvent> _queue = [];

  late StreamSubscription _flushSubscription;

  StatsigLogger(this._network) {
    _flushSubscription =
        Future.delayed(Duration(milliseconds: loggingIntervalMillis))
            .asStream()
            .listen((event) => _flush());
  }

  void enqueue(StatsigEvent event) {
    _queue.add(event);

    if (_queue.length >= maxQueueLength) {
      _flush();
    }
  }

  Future shutdown() async {
    _flushSubscription.cancel();
    await _flush(true);
  }

  Future _flush([bool isShuttingDown = false]) async {
    if (_queue.length == 0) {
      return;
    }

    var events = _queue;
    _queue = [];
    await _network.sendEvents(events);
  }
}
