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
    setUp(() async {
      final interceptor = nock('https://featuregates.org')
          .post('/v1/initialize', (body) => true)
        ..reply(200, TestData.initializeResponse);
      await Statsig.initialize('a-key');

      expect(interceptor.isDone, true);
    });

    group('Feature Gates', () {
      test('returns gate value from network', () {
        expect(Statsig.checkGate('a_gate'), true);
      });
      test('returns false by default', () {
        expect(Statsig.checkGate('no_gate'), false);
      });
      test('returns default value for gate', () {
        expect(Statsig.checkGate('no_gate', true), true);
      });
    });

    group('Configs', () {
      test('returns config from network', () {
        var config = Statsig.getConfig("a_config");

        expect(config.name, "a_config");
        expect(config.get("a_string_value"), "foo");
        expect(config.get("a_bool_value"), true);
        expect(config.get("a_number_value"), 420);
      });

      test('returns and empty config by default', () {
        var config = Statsig.getConfig("no_config");
        expect(config.name, "no_config");
        expect(config.get("a_string_value"), null);
      });

      test('returns default values', () {
        var config = Statsig.getConfig("no_config");
        expect(config.name, "no_config");
        expect(config.get("a_string_value", "bar"), "bar");
        expect(config.get("a_bool_value", true), true);
        expect(config.get("a_number_value", 7), 7);
      });
    });
  });

  group('Statsig when Uninitialized', () {
    test('returns default gate value', () {
      expect(Statsig.checkGate('a_gate', true), true);
      expect(Statsig.checkGate('a_gate'), false);
    });
  });
}
