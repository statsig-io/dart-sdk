@Timeout(Duration(seconds: 1))

import 'dart:async';
import 'dart:convert';

import 'package:nock/nock.dart';
import 'package:statsig/src/network_service.dart';
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

  group('Failed Event Logging', () {
    Map? logs;
    Completer<bool> completer = new Completer();

    setUp(() async {
      final interceptor =
          nock('https://statsigapi.net').post('/v1/initialize', (body) => true)
            ..persist()
            ..reply(200, TestData.initializeResponse);
      await Statsig.initialize('a-key');

      expect(interceptor.isDone, true);

      completer = new Completer();
      logs = null;
    });

    test('retries logs that previously failed', () async {
      var calls = 0;
      var badLogsInterceptor =
          nock('https://statsigapi.net').post('/v1/rgstr', (body) => true)
            ..persist()
            ..reply(500, "{}")
            ..onReply(() {
              if (++calls >= 3) {
                completer.complete(true);
              }
            });

      NetworkService.initialBackoffSeconds = 0;
      Statsig.getConfig('a_config');
      await Statsig.shutdown();

      await completer.future;
      completer = new Completer();
      badLogsInterceptor.cancel();

      nock('https://statsigapi.net').post('/v1/rgstr', (body) {
        logs = jsonDecode(utf8.decode(body)) as Map;
        return true;
      })
        ..reply(200, "{}")
        ..onReply(() {
          completer.complete(true);
        });

      await Statsig.initialize('a-key');
      await completer.future;

      var event = (logs as Map)['events'][0] as Map;
      expect(event['eventName'], "statsig::config_exposure");
      expect(event['metadata'], {"config": "a_config", "ruleID": "a_rule_id"});
      expect((logs as Map)['statsigMetadata']['sdkType'], 'dart');
    });
  });
}
