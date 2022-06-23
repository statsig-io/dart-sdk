@Timeout(Duration(seconds: 1))

import 'dart:async';
import 'dart:ffi';

import 'package:nock/nock.dart';
import 'package:statsig/statsig.dart';
import 'package:test/test.dart';

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
        ..reply(200,
            '{"feature_gates":{},"dynamic_configs":{},"layer_configs":{},"has_updates":true,"time":1621637839}');
      await Statsig.initialize('a-key');

      expect(interceptor.isDone, true);

      completer = new Completer();
      loggingStub = nock('https://api.statsig.com').post('/v1/rgstr', (body) {
        request = body;
        return true;
      })
        ..reply(200, '{}')
        ..onReply(() => completer?.complete(true));
    });

    test('logs gate exposures', () async {
      Statsig.checkGate('a_gate');
      await completer?.future;

      expect(loggingStub?.isDone, true);
      expect(request is Map, true);
    });
  });
}
