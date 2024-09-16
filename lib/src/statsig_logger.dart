import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:statsig/statsig.dart';

import 'disk_util/disk_util.dart';
import 'network_service.dart';
import 'statsig_event.dart';

const maxQueueLength = 1000;
const loggingIntervalMillis = 10000;
const dedeupeInterval = 10 * 60 * 1000;
const failedEventsFilename = "failed_events.json";

class StatsigLogger {
  final NetworkService _network;
  List<StatsigEvent> _queue = [];
  int _flushBatchSize = 50;
  Map<String, int> seenExposures = {};

  late Timer _flushTimer;

  StatsigLogger(this._network) {
    _loadFailedLogs();
    _flushTimer =
        Timer.periodic(Duration(milliseconds: loggingIntervalMillis), (_) {
      flush();
    });
  }

  void enqueue(StatsigEvent event) {
    _queue.add(event);

    if (_queue.length >= _flushBatchSize) {
      flush();
    }
  }

  void logGateExposure(
      String gateName,
      StatsigUser user,
      EvaluationDetails details,
      bool value,
      String ruleID,
      List<dynamic> secondaryExposures) {
    var key = gateName + value.toString() + ruleID + details.reason;
    if (!shouldDedupe(key)) {
      enqueue(StatsigEvent.createGateExposure(
          user, gateName, value, ruleID, secondaryExposures, details));
    }
  }

  void logConfigExposure(
      String configName,
      StatsigUser user,
      EvaluationDetails details,
      String ruleID,
      List<dynamic> secondaryExposures) {
    var key = configName + ruleID + details.reason;
    if (!shouldDedupe(key)) {
      enqueue(StatsigEvent.createConfigExposure(
          user, configName, ruleID, secondaryExposures, details));
    }
  }

  void logLayerExposure(
      String layerName,
      StatsigUser user,
      EvaluationDetails details,
      String ruleID,
      List<dynamic> secondaryExposures,
      bool isExplicit,
      String allocatedExperiment,
      String parameterName) {
    var key = layerName +
        ruleID +
        allocatedExperiment +
        parameterName +
        isExplicit.toString() +
        details.reason;
    if (!shouldDedupe(key)) {
      enqueue(StatsigEvent.createLayerExposure(
          user,
          layerName,
          ruleID,
          allocatedExperiment,
          parameterName,
          isExplicit,
          secondaryExposures,
          details));
    }
  }

  void clear() {
    seenExposures = {};
  }

  bool shouldDedupe(String key) {
    var now = DateTime.now().millisecondsSinceEpoch;
    var last = seenExposures[key] ?? 0;
    if (last >= now - dedeupeInterval) {
      return true;
    }
    seenExposures[key] = now;
    return false;
  }

  Future shutdown() async {
    _flushTimer.cancel();
    await flush(true);
  }

  Future flush([bool isShuttingDown = false]) async {
    if (_queue.isEmpty) {
      return;
    }

    var events = _queue;
    _queue = [];
    var success = await _network.sendEvents(events);
    if (success) {
      return;
    }

    if (isShuttingDown) {
      await DiskUtil.instance.write(failedEventsFilename, json.encode(events));
    } else {
      _flushBatchSize = min(_flushBatchSize * 2, maxQueueLength);
      _queue += events;
    }
  }

  Future _loadFailedLogs() async {
    var contents = await DiskUtil.instance
        .read(failedEventsFilename, destroyAfterReading: true);
    if (!contents.startsWith("[") || !contents.endsWith("]")) {
      return;
    }

    var events = json.decode(contents);
    if (events is List) {
      for (var element in events) {
        _queue.add(StatsigEvent.fromJson(element));
      }
    }

    if (_queue.isNotEmpty) {
      flush();
    }
  }
}
