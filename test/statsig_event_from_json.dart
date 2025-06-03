@Timeout(Duration(seconds: 1))

import 'package:statsig/src/statsig_event.dart';
import 'package:test/test.dart';

void main() {
  group('Statsig Event From JSON', () {
    test('Does not throw when user null', () {
      var json = {
        "eventName": "test_event",
        "time": 1234567890,
        "metadata": {"key": "value"},
        "secondaryExposures": ["exposure1", "exposure2"],
        "value": 42.0,
        "user": null,
      };

      expect(() => StatsigEvent.fromJson(json), returnsNormally);
    });

    test('Does not throw when user is missing', () {
      var json = {
        "eventName": "test_event",
        "time": 1234567890,
        "metadata": {"key": "value"},
        "secondaryExposures": ["exposure1", "exposure2"],
        "value": 42.0,
      };

      expect(() => StatsigEvent.fromJson(json), returnsNormally);
    });
  });
}
