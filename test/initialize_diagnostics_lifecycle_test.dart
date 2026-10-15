import 'dart:convert';

import 'package:statsig/src/network_service.dart';
import 'package:statsig/statsig.dart';
import 'package:test/test.dart';

import 'helpers/diagnostics_lifecycle_harness.dart';
import 'test_data.dart';

void main() {
  late DiagnosticsLifecycleHarness harness;
  late int originalBackoff;

  setUp(() async {
    originalBackoff = NetworkService.initialBackoffSeconds;
    harness = await DiagnosticsLifecycleHarness.start();
  });
  tearDown(() async {
    await harness.stop();
    NetworkService.initialBackoffSeconds = originalBackoff;
  });

  test('rejected SDK key emits failed processing and overall outcomes',
      () async {
    harness.reply = InitializeReply(
        200,
        jsonEncode({
          'hashed_sdk_key_used': 'different-key-hash',
          'diagnostics': {'initialize': 1},
        }));
    await harness.initialize(forceSampling: false);
    await harness.flush();

    final markers = harness.markers('initialize');
    expectPairedMarkers(markers, 8);
    expect(markers.last['success'], isFalse);
    expect(
        markers.singleWhere(
            (m) => m['step'] == 'process' && m['action'] == 'end')['success'],
        isFalse);
    expect(Statsig.getConfig('a_config').details.reason, 'NoValues');
  });

  test('accepted response preserves values and normal response sampling',
      () async {
    final response = jsonDecode(TestData.initializeResponse) as Map;
    response['diagnostics'] = {'initialize': 1};
    harness.reply = InitializeReply(200, jsonEncode(response));
    await harness.initialize(forceSampling: false);
    await harness.flush();

    final markers = harness.markers('initialize');
    expectPairedMarkers(markers, 8);
    expect(markers.last['success'], isTrue);
    expect(Statsig.getConfig('a_config').details.reason, 'Network:Recognized');
  });

  test('HTTP204 preserves the accepted not-modified outcome', () async {
    harness.reply = InitializeReply(204, '');
    await harness.initialize();
    await harness.flush();

    final markers = harness.markers('initialize');
    expectPairedMarkers(markers, 8);
    expect(markers.last['success'], isTrue);
    expect(
        markers.singleWhere((m) =>
            m['step'] == 'network_request' &&
            m['action'] == 'end')['statusCode'],
        204);
    expect(Statsig.getConfig('a_config').details.reason,
        'NetworkNotModified:Unrecognized');
  });

  for (final body in ['{malformed', '[]']) {
    test('invalid 2xx body $body emits one failed request end', () async {
      harness.reply = InitializeReply(200, body);
      await harness.initialize();
      await harness.flush();

      final markers = harness.markers('initialize');
      expectPairedMarkers(markers, 6);
      final end = markers.singleWhere(
          (m) => m['step'] == 'network_request' && m['action'] == 'end');
      expect(end['success'], isFalse);
      expect(end['statusCode'], 200);
      expect(markers.where((m) => m['step'] == 'process'), isEmpty);
      expect(markers.last['success'], isFalse);
    });
  }

  test('HTTP failure omits response processing', () async {
    harness.reply = InitializeReply(400, '');
    await harness.initialize();
    await harness.flush();

    final markers = harness.markers('initialize');
    expectPairedMarkers(markers, 6);
    expect(markers.where((m) => m['step'] == 'process'), isEmpty);
    expect(markers.last['success'], isFalse);
    expect(Statsig.getConfig('a_config').details.reason, 'NoValues');
  });

  test('timeout closes the request once and ignores its late success',
      () async {
    final delayed =
        InitializeReply(200, TestData.initializeResponse, held: true);
    harness.reply = delayed;
    await harness.initialize(timeout: 1);
    await harness.flush();

    final markers = harness.markers('initialize');
    expectPairedMarkers(markers, 6);
    expect(markers.last['success'], isFalse);
    expect(
        markers.singleWhere((m) =>
            m['step'] == 'network_request' && m['action'] == 'end')['success'],
        isFalse);
    delayed.release();
    await delayed.handled;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await harness.flush();
    expect(harness.markers('initialize'), markers);
    expect(Statsig.getConfig('a_config').details.reason, 'NoValues');
  });

  test('timeout during retry backoff prevents further attempts', () async {
    NetworkService.initialBackoffSeconds = 2;
    harness.reply = InitializeReply(500, '');
    await harness.initialize(timeout: 1);
    await harness.flush();

    final markers = harness.markers('initialize');
    expectPairedMarkers(markers, 6);
    expect(markers.last['success'], isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    expect(harness.initializeRequests, 1);
    await harness.flush();
    expect(harness.markers('initialize'), markers);
  });

  test('retry exhaustion pairs all four actual attempts', () async {
    NetworkService.initialBackoffSeconds = 0;
    harness.reply = InitializeReply(500, '');
    await harness.initialize();
    await harness.flush();

    final markers = harness.markers('initialize');
    expectPairedMarkers(markers, 12);
    expect(harness.initializeRequests, 4);
    expect(markers.where((m) => m['step'] == 'process'), isEmpty);
    expect(markers.last['success'], isFalse);
  });
}
