@Timeout(Duration(seconds: 1))

import 'dart:async';
import 'dart:convert';

import 'package:nock/nock.dart';
import 'package:statsig/statsig.dart';
import 'package:test/test.dart';

import 'test_data.dart';

void main() {
  setUpAll(() {
    nock.init();
  });

  setUp(() {
    Statsig.reset();
    nock.cleanAll();
  });

  group('Statsig when Initialized', () {
    Interceptor? loggingStub;
    Map? logs;
    Completer<bool>? completer;

    setUp(() async {
      final interceptor = nock('https://statsigapi.net')
          .post('/v1/initialize', (body) => true)
        ..reply(200, TestData.initializeResponse);
      await Statsig.initialize('a-key',
          StatsigUser(userId: "a-user", privateAttributes: {"secret": "shh"}));

      expect(interceptor.isDone, true);

      completer = Completer();
      loggingStub = nock('https://statsigapi.net').post('/v1/rgstr', (body) {
        logs = jsonDecode(utf8.decode(body)) as Map;
        return true;
      })
        ..reply(200, '{}')
        ..onReply(() => completer?.complete(true));
      logs = null;
    });

    group("User Object", () {
      test('does not log private attributes', () async {
        Statsig.checkGate('a_gate');
        Statsig.shutdown();
        await completer?.future;

        expect(loggingStub?.isDone, true);

        var event = (logs as Map)['events'][0] as Map;
        expect(event['user'], {
          'userID': 'a-user',
          'email': null,
          'ip': null,
          'country': null,
          'locale': null,
          'appVersion': null,
          'custom': null,
          'customIDs': null
        });
      });
    });

    group("Feature Gates", () {
      test('does not log gates that do not exist', () async {
        Statsig.checkGate('not_a_gate');
        Statsig.shutdown();
        expect(logs, null);
      });

      test('logs gate exposures', () async {
        Statsig.checkGate('a_gate');
        Statsig.shutdown();
        await completer?.future;

        expect(loggingStub?.isDone, true);

        var event = (logs as Map)['events'][0] as Map;
        expect(event['eventName'], "statsig::gate_exposure");
        expect(event['metadata'],
            {"gate": "a_gate", "gateValue": "true", "ruleID": "a_rule_id"});
        expect((logs as Map)['statsigMetadata']['sdkType'], 'dart-client');
      });
    });

    group("Dynamic Configs", () {
      test('does not log configs that do not exist', () async {
        Statsig.checkGate('not_a_config');
        Statsig.shutdown();
        expect(logs, null);
      });

      test('logs config exposures', () async {
        Statsig.getConfig('a_config');
        Statsig.shutdown();
        await completer?.future;

        expect(loggingStub?.isDone, true);

        var event = (logs as Map)['events'][0] as Map;
        expect(event['eventName'], "statsig::config_exposure");
        expect(
            event['metadata'], {"config": "a_config", "ruleID": "a_rule_id"});
        expect((logs as Map)['statsigMetadata']['sdkType'], 'dart-client');
      });
    });
  });
}
