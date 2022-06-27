@Timeout(Duration(seconds: 1))

import 'dart:async';
import 'dart:ffi';
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
    dynamic request;
    Completer<bool>? completer;

    setUp(() async {
      final interceptor = nock('https://api.statsig.com').post('/v1/initialize')
        ..reply(200, TestData.initializeResponse);
      await Statsig.initialize('a-key');

      expect(interceptor.isDone, true);

      completer = new Completer();
      loggingStub = nock('https://api.statsig.com').post('/v1/rgstr', (body) {
        request = jsonDecode(utf8.decode(body)) as Map;
        return true;
      })
        ..reply(200, '{}')
        ..onReply(() => completer?.complete(true));
      request = null;
    });

    group("Feature Gates", () {
      test('does not log gates that do not exist', () async {
        Statsig.checkGate('not_a_gate');
        expect(request, null);
      });

      test('logs gate exposures', () async {
        Statsig.checkGate('a_gate');
        await completer?.future;

        expect(loggingStub?.isDone, true);
        expect(request is Map, true);

        expect(request, {
          "events": [
            {
              "eventName": "statsig::gate_exposure",
              "metadata": {
                "gate": "a_gate",
                "gateValue": "true",
                "ruleID": "a_rule_id"
              }
            }
          ],
          "statsigMetadata": {"sdkType": "dart", "sdkVersion": "1.0.0"}
        });
      });
    });

    group("Dynamic Configs", () {
      test('does not log configs that do not exist', () async {
        Statsig.checkGate('not_a_config');
        expect(request, null);
      });

      test('logs config exposures', () async {
        Statsig.checkGate('a_gate');
        await completer?.future;

        expect(loggingStub?.isDone, true);
        expect(request is Map, true);

        expect(request, {
          "events": [
            {
              "eventName": "statsig::config_exposure",
              "metadata": {"config": "a_config", "ruleID": "a_rule_id"}
            }
          ],
          "statsigMetadata": {"sdkType": "dart", "sdkVersion": "1.0.0"}
        });
      });
    });
  });
}
