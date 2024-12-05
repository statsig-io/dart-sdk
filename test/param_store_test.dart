@Timeout(Duration(seconds: 1))

import 'dart:async';

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
    Completer<bool>? completer;

    setUp(() async {
      final interceptor = nock('https://featuregates.org')
          .post('/v1/initialize', (body) => true)
        ..reply(200, TestData.paramStoreResponse);
      await Statsig.initialize(
          'a-key',
          StatsigUser(userId: "a-user", privateAttributes: {"secret": "shh"}),
          StatsigOptions(environment: "staging"));

      expect(interceptor.isDone, true);

      completer = Completer();
      nock('https://statsigapi.net').post('/v1/rgstr', (body) {
        return true;
      })
        ..reply(200, '{}')
        ..onReply(() => completer?.complete(true));
    });

    group("Param Store Check", () {
      test('gets the correct value with no default for string array', () async {
        var store = Statsig.getParameterStore("a_store");
        var values = store.get("enabled_values");
        expect(values, ['123', '124', '125', '126', '127']);
      });
      test('gets the correct value with no default for number array', () async {
        var store = Statsig.getParameterStore("a_store");
        var values = store.get("enabled_values_v4");
        expect(values, [1, 4, 6]);
      });
      test('gets the correct value with default for string array', () async {
        var store = Statsig.getParameterStore("a_store");
        var defaultValue = ['1', '2', '3'];
        var values = store.getArray("enabled_values", defaultValue);
        expect(values, ['123', '124', '125', '126', '127']);
      });
      test('gets the correct value with default for number array', () async {
        var store = Statsig.getParameterStore("a_store");
        var defaultValue = [1, 2, 3];
        var values = store.getArray("enabled_values_v4", defaultValue);
        expect(values, [1, 4, 6]);
      });
      test('gets the correct value with default for config', () async {
        var config = Statsig.getConfig("a_config");
        var defaultValue = ['1', '2', '3'];
        var values = config.getArray("a_array_value", defaultValue);
        expect(values, ['123', '124', '125', '126', '127']);
      });
      test('gets the correct value for mixed map', () async {
        var store = Statsig.getParameterStore("a_store");
        var defaultValue = {
          "test": "default",
          "test2": {"value": 1}
        };
        var values = store.getMap("enabled_values_v2", defaultValue);
        expect(values, {
          "key": "value",
          "key2": {"value": 2},
        });
      });

      test('gets the correct value for string map', () async {
        var store = Statsig.getParameterStore("a_store");
        var defaultValue = {"test": "default"};
        var values = store.getMap("enabled_values_v3", defaultValue);
        expect(values, {
          "key": "value",
          "key2": "value2",
        });
      });
    });
  });
}
