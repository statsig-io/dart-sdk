import 'dart:convert';
import 'package:statsig/src/internal_store.dart';
import 'package:statsig/src/network_service.dart';
import 'package:statsig/statsig.dart';
import 'package:test/test.dart';
import '../test_data.dart';
import 'diagnostics_lifecycle_harness.dart';

void registerDiagnosticsMetadataContract({required bool updateUser}) {
  final context = updateUser ? 'update_user' : 'initialize';
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

  Future<void> run({bool forceSampling = true}) async {
    if (updateUser) {
      final target = harness.reply;
      harness.reply = InitializeReply(200, TestData.initializeResponse);
      await harness.initialize(timeout: 1, forceSampling: forceSampling);
      await harness.flush();
      harness.reply = target;
      await Statsig.updateUser(harness.freshUser('metadata-update'));
    } else {
      await harness.initialize(timeout: 1, forceSampling: forceSampling);
    }
    await harness.flush();
  }

  List<Map<String, dynamic>> markers({bool process = false}) {
    final result = harness.markers(context);
    expectPairedMarkers(result, (updateUser ? 4 : 6) + (process ? 2 : 0));
    return result;
  }

  Map<String, dynamic> requestEnd(List<Map<String, dynamic>> values) =>
      values.singleWhere(
          (m) => m['step'] == 'network_request' && m['action'] == 'end');

  test('$context region and applied snapshot preserve normal sampling',
      () async {
    final payload = jsonDecode(TestData.initializeResponse) as Map;
    payload['time'] = 12345;
    payload['diagnostics'] = {context: 1};
    harness.reply = InitializeReply(200, jsonEncode(payload),
        headers: {'x-statsig-region': 'actual-region'});
    await run(forceSampling: false);
    final values = markers(process: true);
    expect(requestEnd(values)['sdkRegion'], 'actual-region');
    expect(requestEnd(values).containsKey('error'), isFalse);
    final details = Statsig.getConfig('a_config').details;
    expect(values.last['evaluationDetails'], {
      'reason': 'Network',
      'lcut': 12345,
      'receivedAt': details.receivedAt,
    });
    expect(details.receivedAt, greaterThan(0));
    expect(values.last.containsKey('error'), isFalse);
  });

  test('$context HTTP error retains actual status and region', () async {
    harness.reply = InitializeReply(566, 'unstructured-response-body',
        headers: {'x-statsig-region': 'failure-region'});
    await run();
    final values = markers();
    final end = requestEnd(values);
    expect(end['sdkRegion'], 'failure-region');
    expect(end['statusCode'], 566);
    expect(end['error']['name'], 'HttpError');
    expect(end['error']['code'], '566');
    expect(end['error']['message'], contains('566'));
    expect(
        end['error']['message'], isNot(contains('unstructured-response-body')));
    expect(values.last['error'], end['error']);
    expect(values.last['evaluationDetails'], {'reason': 'NoValues'});
  });

  test('$context malformed body retains known status and region', () async {
    harness.reply = InitializeReply(200, '{invalid',
        headers: {'x-statsig-region': 'parse-region'});
    await run();
    final values = markers();
    final end = requestEnd(values);
    expect(end['statusCode'], 200);
    expect(end['sdkRegion'], 'parse-region');
    expect(end['error']['name'], 'FormatException');
    expect(end['error']['message'], isA<String>());
    expect(values.last['error'], end['error']);
    expect(values.last['evaluationDetails'], {'reason': 'NoValues'});
  });

  test('$context rejected key reports application error and successful HTTP',
      () async {
    harness.reply = InitializeReply(
        200,
        jsonEncode({
          'hashed_sdk_key_used': 'different-key-hash',
          'diagnostics': {context: 1},
        }));
    await run(forceSampling: false);
    final values = markers(process: true);
    expect(requestEnd(values)['success'], isTrue);
    expect(requestEnd(values).containsKey('error'), isFalse);
    final end = values
        .singleWhere((m) => m['step'] == 'process' && m['action'] == 'end');
    expect(end['error']['name'], 'SDKKeyMismatch');
    expect(end['error']['message'], isNot(contains('different-key-hash')));
    expect(values.last['error'], end['error']);
    expect(values.last['evaluationDetails'], {'reason': 'NoValues'});
  });

  test('$context active timeout has a terminal timeout error', () async {
    harness.reply =
        InitializeReply(200, TestData.initializeResponse, held: true);
    await run();
    final values = markers();
    expect(requestEnd(values)['error']['name'], 'TimeoutError');
    expect(values.last['error'], requestEnd(values)['error']);
    expect(values.last['evaluationDetails'], {'reason': 'NoValues'});
    expect(requestEnd(values).containsKey('sdkRegion'), isFalse);
  });

  test('$context backoff timeout overrides the last HTTP failure outcome',
      () async {
    NetworkService.initialBackoffSeconds = 2;
    harness.reply =
        InitializeReply(500, '', headers: {'x-statsig-region': 'retry-region'});
    await run();
    final values = markers();
    expect(requestEnd(values)['error']['name'], 'HttpError');
    expect(values.last['error']['name'], 'TimeoutError');
    expect(values.last['evaluationDetails'], {'reason': 'NoValues'});
  });

  test('$context disconnect omits unavailable status and region', () async {
    harness.reply = InitializeReply(200, '', disconnect: true);
    await run();
    final values = markers();
    final end = requestEnd(values);
    expect(end['error']['name'], isIn(['ClientException', 'SocketException']));
    expect(end['error']['message'], isA<String>());
    expect(end.containsKey('statusCode'), isFalse);
    expect(end.containsKey('sdkRegion'), isFalse);
    expect(values.last['error'], end['error']);
  });

  test('$context unforced null failure remains unsampled', () async {
    harness.reply = InitializeReply(566, '');
    await run(forceSampling: false);
    expect(
        harness.events.where((e) => e['eventName'] == 'statsig::diagnostics'),
        isEmpty);
  });

  test('$context failed refetch snapshots the persisted cache source',
      () async {
    final user = harness.freshUser('metadata-cache');
    await harness.initialize(user: user);
    final previous = Statsig.getConfig('a_config').details;
    await harness.flush();
    var persisted = false;
    for (var i = 0; i < 200; i++) {
      if (await InternalStore().readCache(user) != null) {
        persisted = true;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(persisted, isTrue, reason: 'await disk before relying on cache');
    harness.events.clear();
    harness.reply =
        InitializeReply(566, '', headers: {'x-statsig-region': 'cache-region'});
    if (updateUser) {
      await Statsig.updateUser(user);
    } else {
      await Statsig.shutdown();
      Statsig.reset();
      await harness.initialize(user: user);
    }
    await harness.flush();
    final values = markers();
    expect(values.last['success'], isFalse);
    expect(values.last['evaluationDetails'], {
      'reason': 'Cache',
      'lcut': previous.lcut,
      'receivedAt': previous.receivedAt,
    });
    expect(Statsig.getConfig('a_config').details.reason, 'Cache:Recognized');
    expect(requestEnd(values)['sdkRegion'], 'cache-region');
  });
}
