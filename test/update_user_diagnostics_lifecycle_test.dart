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

  Future<void> warmup({bool forceSampling = true}) async {
    await harness.initialize(timeout: 1, forceSampling: forceSampling);
    await harness.flush();
  }

  String responseWithValue(String value) {
    final response = jsonDecode(TestData.initializeResponse) as Map;
    final config = (response['dynamic_configs'] as Map).values.single as Map;
    config['value']['a_key'] = value;
    return jsonEncode(response);
  }

  test('rejected SDK key emits a failed update outcome with response sampling',
      () async {
    await warmup(forceSampling: false);
    harness.reply = InitializeReply(
        200,
        jsonEncode({
          'hashed_sdk_key_used': 'different-key-hash',
          'diagnostics': {'update_user': 1},
        }));
    await Statsig.updateUser(harness.freshUser('rejected-update'));
    await harness.flush();

    final markers = harness.markers('update_user');
    expectPairedMarkers(markers, 6);
    expect(markers.last['success'], isFalse);
    expect(
        markers.singleWhere(
            (m) => m['step'] == 'process' && m['action'] == 'end')['success'],
        isFalse);
    expect(Statsig.getConfig('a_config').details.reason, 'NoValues');
  });

  for (final body in ['{malformed', '[]']) {
    test('invalid update 2xx body $body emits one failed request end',
        () async {
      await warmup();
      harness.reply = InitializeReply(200, body);
      await Statsig.updateUser(harness.freshUser('invalid-update'));
      await harness.flush();

      final markers = harness.markers('update_user');
      expectPairedMarkers(markers, 4);
      final end = markers.singleWhere(
          (m) => m['step'] == 'network_request' && m['action'] == 'end');
      expect(end['success'], isFalse);
      expect(end['statusCode'], 200);
      expect(markers.where((m) => m['step'] == 'process'), isEmpty);
      expect(markers.last['success'], isFalse);
      expectPairedMarkers(harness.markers('initialize'), 8);
    });
  }

  test('failed update omits processing and keeps initialization isolated',
      () async {
    await warmup();
    harness.reply = InitializeReply(400, '');
    await Statsig.updateUser(harness.freshUser('failed-update'));
    await harness.flush();

    final markers = harness.markers('update_user');
    expectPairedMarkers(markers, 4);
    expect(markers.where((m) => m['step'] == 'process'), isEmpty);
    expect(markers.last['success'], isFalse);
    expectPairedMarkers(harness.markers('initialize'), 8);
    expect(Statsig.getConfig('a_config').details.reason, 'NoValues');
  });

  test('late timed-out response cannot add a terminal to the next update',
      () async {
    await warmup();
    final delayed =
        InitializeReply(200, responseWithValue('obsolete'), held: true);
    harness.reply = delayed;
    await Statsig.updateUser(harness.freshUser('timed-out-update'));
    await harness.flush();
    final first = harness.markers('update_user');
    expectPairedMarkers(first, 4);
    expect(first.last['success'], isFalse);

    harness.reply = InitializeReply(200, responseWithValue('current'));
    await Statsig.updateUser(harness.freshUser('next-update'));
    await harness.flush();
    final second = harness.markers('update_user', eventCount: 2, index: 1);
    expectPairedMarkers(second, 6);
    expect(second.last['success'], isTrue);

    delayed.release();
    await delayed.handled;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await harness.flush();
    expect(harness.markers('update_user', eventCount: 2), first);
    expect(harness.markers('update_user', eventCount: 2, index: 1), second);
    expect(Statsig.getConfig('a_config').details.reason, 'Network:Recognized');
    expect(Statsig.getConfig('a_config').value['a_key'], 'current');
    expectPairedMarkers(harness.markers('initialize'), 8);
  });

  test('update timeout during backoff prevents further attempts', () async {
    await warmup();
    NetworkService.initialBackoffSeconds = 2;
    harness.reply = InitializeReply(500, '');
    await Statsig.updateUser(harness.freshUser('backoff-update'));
    await harness.flush();

    final markers = harness.markers('update_user');
    expectPairedMarkers(markers, 4);
    expect(markers.last['success'], isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    expect(harness.initializeRequests, 2); // Warm initialize, then one attempt.
    await harness.flush();
    expect(harness.markers('update_user'), markers);
  });

  test('update retry exhaustion pairs all four actual attempts', () async {
    await warmup();
    NetworkService.initialBackoffSeconds = 0;
    harness.reply = InitializeReply(500, '');
    await Statsig.updateUser(harness.freshUser('retry-update'));
    await harness.flush();

    final markers = harness.markers('update_user');
    expectPairedMarkers(markers, 10);
    expect(harness.initializeRequests, 5);
    expect(markers.where((m) => m['step'] == 'process'), isEmpty);
    expect(markers.last['success'], isFalse);
  });

  test('repeated same-user updates emit independent balanced events', () async {
    await warmup();
    final user = harness.freshUser('repeated-update');
    await Statsig.updateUser(user);
    await Statsig.updateUser(user);
    await harness.flush();

    for (var i = 0; i < 2; i++) {
      final markers = harness.markers('update_user', eventCount: 2, index: i);
      expectPairedMarkers(markers, 6);
      expect(markers.last['success'], isTrue);
      expect(markers.where((m) => m['step'] == 'load_cache'), isEmpty);
    }
    expectPairedMarkers(harness.markers('initialize'), 8);
  });

  test('superseded request keeps deliberate suppression and store isolation',
      () async {
    await warmup();
    final delayed =
        InitializeReply(200, responseWithValue('obsolete'), held: true);
    harness.reply = delayed;
    final first = Statsig.updateUser(harness.freshUser('superseded-update'));
    await delayed.started;

    harness.reply = InitializeReply(200, responseWithValue('current'));
    await Statsig.updateUser(harness.freshUser('current-update'));
    delayed.release();
    await first;
    await harness.flush();

    final markers = harness.markers('update_user');
    expectPairedMarkers(markers, 6);
    expect(markers.last['success'], isTrue);
    expect(Statsig.getConfig('a_config').details.reason, 'Network:Recognized');
    expect(Statsig.getConfig('a_config').value['a_key'], 'current');
    expectPairedMarkers(harness.markers('initialize'), 8);
  });
}
