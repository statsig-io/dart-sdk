import 'package:nock/nock.dart';
import 'package:statsig/src/utils.dart';
import 'package:statsig/statsig.dart';
import 'package:test/test.dart';

var gateAlwaysOnKey = 'always_on';
var gateAlwaysOnHashKey = Utils.hash(gateAlwaysOnKey);

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
      final interceptor = nock('https://api.statsig.com').post('/v1/initialize')
        ..reply(200, '''
        {
          "feature_gates": {
            "a_gate": true
          }, 
          "dynamic_configs": {
            "a_config": {
              "value": {
                "a_string_value": "foo", 
                "a_bool_value": true,
                "a_number_value": 420
              }
            }
          }, 
          "layer_configs": {}, 
          "has_updates": true, 
          "time": 1621637839}
        ''');
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

        expect(config?.name, "a_config");
        expect(config?.get("a_string_value"), "foo");
        expect(config?.get("a_bool_value"), true);
        expect(config?.get("a_number_value"), 420);
      });

      test('returns and empty config by default', () {
        var config = Statsig.getConfig("no_config");
        expect(config?.name, "no_config");
        expect(config?.get("a_string_value"), null);
      });

      test('returns default values', () {
        var config = Statsig.getConfig("no_config");
        expect(config?.name, "no_config");
        expect(config?.get("a_string_value", "bar"), "bar");
        expect(config?.get("a_bool_value", true), true);
        expect(config?.get("a_number_value", 7), 7);
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
