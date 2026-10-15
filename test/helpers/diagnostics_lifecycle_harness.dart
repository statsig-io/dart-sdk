import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:statsig/statsig.dart';
import 'package:test/test.dart';

import '../test_data.dart';

class InitializeReply {
  final int status;
  final String body;
  final Map<String, String> headers;
  final bool disconnect;
  final Completer<void>? _gate;
  final Completer<void> _handled = Completer<void>();
  final Completer<void> _started = Completer<void>();

  InitializeReply(this.status, this.body,
      {bool held = false, this.headers = const {}, this.disconnect = false})
      : _gate = held ? Completer<void>() : null;

  Future<void> get handled => _handled.future;
  Future<void> get started => _started.future;

  void release() {
    final gate = _gate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }
}

/// Exercises the public client and captures its actual HTTP log payloads.
class DiagnosticsLifecycleHarness {
  final HttpServer _server;
  final List<Map<String, dynamic>> events = [];
  final List<InitializeReply> _replies = [];
  InitializeReply reply = InitializeReply(200, TestData.initializeResponse);
  int initializeRequests = 0;

  DiagnosticsLifecycleHarness._(this._server);

  static Future<DiagnosticsLifecycleHarness> start() async {
    Statsig.reset();
    final harness = DiagnosticsLifecycleHarness._(
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
    harness._server.listen(harness._handle);
    return harness;
  }

  Future<void> _handle(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    if (request.uri.path == '/initialize') {
      initializeRequests++;
      final current = reply;
      _replies.add(current);
      if (!current._started.isCompleted) current._started.complete();
      final gate = current._gate;
      if (gate != null) await gate.future;
      try {
        if (current.disconnect) {
          final socket =
              await request.response.detachSocket(writeHeaders: false);
          socket.destroy();
          return;
        }
        request.response.statusCode = current.status;
        current.headers.forEach(request.response.headers.set);
        request.response.write(current.body);
        await request.response.close();
      } on IOException {
        // A timed-out request may already have closed its connection.
      } finally {
        if (!current._handled.isCompleted) current._handled.complete();
      }
    } else if (request.uri.path == '/rgstr') {
      final payload = jsonDecode(body) as Map;
      events.addAll((payload['events'] as List)
          .map((event) => Map<String, dynamic>.from(event as Map)));
      request.response.write('{"success":true}');
      await request.response.close();
    } else {
      request.response.statusCode = 404;
      await request.response.close();
    }
  }

  StatsigUser freshUser(String label) =>
      StatsigUser(userId: '$label-${DateTime.now().microsecondsSinceEpoch}');

  Future<void> initialize(
      {int timeout = 3, bool forceSampling = true, StatsigUser? user}) async {
    await Statsig.initialize(
        'a-key',
        user ?? freshUser('diagnostics-init'),
        StatsigOptions(
            api: 'http://127.0.0.1:${_server.port}',
            initTimeout: timeout,
            forceDiagnosticsSampling: forceSampling));
  }

  Future<void> flush() async => await Statsig.flush();

  List<Map<String, dynamic>> markers(String context,
      {int eventCount = 1, int index = 0}) {
    final matching = events.where((event) =>
        event['eventName'] == 'statsig::diagnostics' &&
        event['metadata']['context'] == context);
    expect(matching, hasLength(eventCount),
        reason: 'one event per completed operation');
    final encoded = matching.elementAt(index)['metadata']['markers'];
    expect(encoded, isA<String>());
    return (jsonDecode(encoded as String) as List)
        .map((marker) => Map<String, dynamic>.from(marker as Map))
        .toList();
  }

  Future<void> stop() async {
    for (final pending in _replies) {
      pending.release();
    }
    await Statsig.shutdown();
    await _server.close(force: true);
    Statsig.reset();
  }
}

void expectPairedMarkers(List<Map<String, dynamic>> markers, int count) {
  expect(markers, hasLength(count));
  final active = <String>{};
  for (final marker in markers) {
    final key = jsonEncode([marker['key'], marker['step'], marker['attempt']]);
    expect(marker['timestamp'], isA<int>());
    if (marker['action'] == 'start') {
      expect(active.add(key), isTrue, reason: 'no duplicate start for $key');
    } else {
      expect(marker['action'], 'end');
      expect(active.remove(key), isTrue,
          reason: 'exactly one terminal for each started $key');
    }
  }
  expect(active, isEmpty, reason: 'every started phase must terminate');
  expect(markers.first['key'], 'overall');
  expect(markers.first['action'], 'start');
  expect(markers.last['key'], 'overall');
  expect(markers.last['action'], 'end');
}
