import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:statsig/src/disk_util.dart';
import 'package:statsig/src/network_service.dart';
import 'package:statsig/src/statsig_event.dart';

const maxQueueLength = 1000;
const loggingIntervalMillis = 10000;
const failedEventsFilename = "failed_events.json";

class StatsigLogger {
  NetworkService _network;
  List<StatsigEvent> _queue = [];
  int _flushBatchSize = 50;

  late StreamSubscription _flushSubscription;

  StatsigLogger(this._network) {
    _loadFailedLogs();
    _flushSubscription =
        Future.delayed(Duration(milliseconds: loggingIntervalMillis))
            .asStream()
            .listen((event) => _flush());
  }

  void enqueue(StatsigEvent event) {
    _queue.add(event);

    if (_queue.length >= _flushBatchSize) {
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
    var success = await _network.sendEvents(events);
    if (success) {
      return;
    }

    if (isShuttingDown) {
      await DiskUtil.write(failedEventsFilename, json.encode(events));
    } else {
      _flushBatchSize = min(_flushBatchSize * 2, maxQueueLength);
      _queue += events;
    }
  }

  Future _loadFailedLogs() async {
    var contents =
        await DiskUtil.read(failedEventsFilename, destroyAfterReading: true);
    if (!contents.startsWith("[") || !contents.endsWith("]")) {
      return;
    }

    var events = json.decode(contents);
    if (events is List) {
      events.forEach((element) {
        _queue.add(StatsigEvent.fromJson(element));
      });
    }

    if (_queue.length > 0) {
      _flush();
    }
  }
}
