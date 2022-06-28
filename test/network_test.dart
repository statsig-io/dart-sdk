import 'package:nock/nock.dart';
import 'package:statsig/src/network_service.dart';
import 'package:statsig/statsig.dart';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;

void main() {
  NetworkService? networkService = null;

  setUpAll(() {
    nock.init();
  });

  setUp(() {
    nock.cleanAll();
    networkService = NetworkService(StatsigOptions());
  });

  group('Network Service', () {
    test('should pass', () async {
      final interceptor = nock('https://api.statsig.com')
          .post('/v1/initialize', (body) => true)
        ..reply(200,
            '{"feature_gates": {}, "dynamic_configs": {}, "layer_configs": {}, "has_updates": true, "time": 1621637839}');

      final response = await networkService?.initialize(StatsigUser());

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
