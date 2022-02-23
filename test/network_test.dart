import 'package:nock/nock.dart';
import 'package:statsig/src/network_service.dart';
import 'package:test/test.dart';

void main() {
  NetworkService? networkService = null;

  setUpAll(() {
    nock.init();
  });

  setUp(() {
    nock.cleanAll();
    networkService = NetworkService();
  });

  group('Network Service', () {
    test('should pass', () async {
      final interceptor = nock('https://api.statsig.com').post('/v1/initialize')
        ..reply(200,
            '{"feature_gates": {}, "dynamic_configs": {}, "layer_configs": {}, "has_updates": true, "time": 1621637839}');
      final response = await networkService?.initialize();

      expect(interceptor.isDone, true);
      expect(response, {
        'feature_gates': {},
        'dynamic_configs': {},
        'layer_configs': {},
        'has_updates': true,
        'time': 1621637839
      });
    });
  });
}
