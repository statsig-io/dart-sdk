@Timeout(Duration(seconds: 1))

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nock/nock.dart';
import 'package:statsig/statsig.dart';
import 'package:test/test.dart';

import 'test_data.dart';

void main() {
  setUpAll(() {
    nock.init();
  });

  setUp(() async {
    // Finish the previous client before replacing its HTTP interceptors.
    await Statsig.shutdown();
    Statsig.reset();
    nock.cleanAll();
  });

  group('Statsig when Initialized', () {
    Interceptor? loggingStub;
    Map? logs;
    Completer<bool>? completer;
    final batches = <Map>[];

    Future<void> initializeClient() async {
      final interceptor = nock('https://featuregates.org')
          .post('/v1/initialize', (body) => true)
        ..reply(200, TestData.initializeResponse);
      await Statsig.initialize(
          'a-key',
          StatsigUser(userId: "a-user", privateAttributes: {"secret": "shh"}),
          StatsigOptions(environment: "staging"));

      expect(interceptor.isDone, true);
    }

    void prepareLoggingCapture() {
      completer = Completer();
      logs = null;
      batches.clear();
      loggingStub = nock('https://statsigapi.net').post('/v1/rgstr', (body) {
        logs = jsonDecode(utf8.decode(body)) as Map;
        batches.add(logs!);
        return true;
      })
        // HTTP success without success:true is persisted as a failed batch.
        ..reply(200, '{"success":true}')
        ..onReply(() => completer?.complete(true));
    }

    Map singleEvent() {
      expect(batches, hasLength(1));
      final events = batches.single['events'] as List;
      expect(events, hasLength(1));
      return events.single as Map;
    }

    setUp(() async {
      // Capture constructor-time replay too, so it cannot silently pass.
      prepareLoggingCapture();
      await initializeClient();
    });

    tearDown(() async {
      await Statsig.shutdown();
    });

    group("User Object", () {
      setUp(() async {
        Statsig.checkGate('a_gate');
        await Statsig.shutdown();
        await completer?.future;

        expect(loggingStub?.isDone, true);
      });

      test('logs user id', () async {
        var event = singleEvent();
        expect("a-user", event['user']['userID']);
      });

      test('does not log private attributes', () async {
        var event = singleEvent();
        expect(null, event['user']['privateAttributes']);
      });

      test('pulls environment off options and adds it to user', () async {
        var event = singleEvent();
        expect({"tier": "staging"}, event['user']['statsigEnvironment']);
      });
    });

    group("Feature Gates", () {
      test('logs unknown gates with an unrecognized reason', () async {
        expect(Statsig.checkGate('not_a_gate'), isFalse);
        expect(logs, null);
        await Statsig.shutdown();
        expect(loggingStub?.isDone, true);
        final event = singleEvent();
        expect(event['eventName'], 'statsig::gate_exposure');
        expect(event['metadata']['gate'], 'not_a_gate');
        expect(event['metadata']['gateValue'], 'false');
        expect(event['metadata']['ruleID'], '');
        expect(event['metadata']['reason'], 'Network:Unrecognized');
      });

      test('logs gate exposures', () async {
        Statsig.checkGate('a_gate');
        await Statsig.shutdown();
        await completer?.future;

        expect(loggingStub?.isDone, true);

        var event = singleEvent();
        expect(event['eventName'], "statsig::gate_exposure");
        expect(event['metadata']["gate"], "a_gate");
        expect(event['metadata']["gateValue"], "true");
        expect(event["metadata"]["ruleID"], "a_rule_id");
        expect(event["metadata"]["reason"], "Network:Recognized");
        expect((logs as Map)['statsigMetadata']['sdkType'], 'dart-client');
      });
    });

    group("Dynamic Configs", () {
      test('logs unknown configs with an unrecognized reason', () async {
        expect(Statsig.getConfig('not_a_config').value, isEmpty);
        expect(logs, null);
        await Statsig.shutdown();
        expect(loggingStub?.isDone, true);
        final event = singleEvent();
        expect(event['eventName'], 'statsig::config_exposure');
        expect(event['metadata']['config'], 'not_a_config');
        expect(event['metadata'], containsPair('ruleID', null));
        expect(event['metadata']['reason'], 'Network:Unrecognized');
      });

      test('logs config exposures', () async {
        Statsig.getConfig('a_config');
        await Statsig.shutdown();
        await completer?.future;

        expect(loggingStub?.isDone, true);

        var event = singleEvent();
        expect(event['eventName'], "statsig::config_exposure");
        expect(event['metadata']["config"], "a_config");
        expect(event["metadata"]["ruleID"], "a_rule_id");
        expect(event["metadata"]["reason"], "Network:Recognized");
        expect((logs as Map)['statsigMetadata']['sdkType'], 'dart-client');
      });
    });

    test('acknowledged batch does not replay into the next client', () async {
      Statsig.checkGate('not_a_gate');
      await Statsig.shutdown();
      expect(singleEvent()['metadata']['gate'], 'not_a_gate');
      expect(
          await File(
                  '${Directory.systemTemp.path}/__statsig__/failed_events.json')
              .exists(),
          isFalse,
          reason:
              'an acknowledged batch must not be replayed by the next client');

      prepareLoggingCapture();
      await initializeClient();
      Statsig.getConfig('a_config');
      await Statsig.shutdown();

      final event = singleEvent();
      expect(event['eventName'], 'statsig::config_exposure');
      expect(event['metadata']['config'], 'a_config');
      expect(event['metadata']['ruleID'], 'a_rule_id');
      expect(event['metadata']['reason'], 'Network:Recognized');
    });
  });
}
