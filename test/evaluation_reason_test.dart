import 'package:nock/nock.dart';
import 'package:statsig/statsig.dart';
import 'package:test/test.dart';

import 'test_data.dart';

// Regression tests for SDKF-31: evaluations after a failed initialization
// were reported as "Uninitialized" even though initialize() had completed.
// The store should pass through Loading and finalize to "NoValues" so that
// "Uninitialized" only ever means initialize() was never called.
void main() {
  setUpAll(() {
    nock.init();
  });

  setUp(() {
    Statsig.reset();
    nock.cleanAll();
  });

  // The disk cache is shared across test runs, so each test uses a unique
  // user to guarantee a cold cache without touching other tests' files.
  StatsigUser freshUser(String name) => StatsigUser(
      userId: "$name-${DateTime.now().microsecondsSinceEpoch}");

  group('before initialize is called', () {
    test('evaluations report Uninitialized', () {
      var config = Statsig.getExperiment('an_experiment');
      expect(config.details.reason, 'Uninitialized');
    });
  });

  group('initialize completes without values (fresh install)', () {
    test('reports NoValues when the network request fails', () async {
      final interceptor = nock('https://featuregates.org')
          .post('/v1/initialize', (body) => true)
        ..reply(400, '');

      await Statsig.initialize('a-key', freshUser('network-fail'));
      expect(interceptor.isDone, true);

      var config = Statsig.getExperiment('an_experiment');
      expect(config.details.reason, 'NoValues');
    });

    test('reports NoValues when the response is for a different sdk key',
        () async {
      nock('https://featuregates.org')
          .post('/v1/initialize', (body) => true)
          .reply(200, '{"hashed_sdk_key_used": "not-my-key-hash"}');

      await Statsig.initialize('a-key', freshUser('key-mismatch'));

      var config = Statsig.getExperiment('an_experiment');
      expect(config.details.reason, 'NoValues');
    });
  });

  group('initialize completes with values', () {
    test('reports Network reasons, not Loading or NoValues', () async {
      nock('https://featuregates.org')
          .post('/v1/initialize', (body) => true)
          .reply(200, TestData.initializeResponse);

      await Statsig.initialize('a-key', freshUser('network-success'));

      expect(Statsig.getConfig('a_config').details.reason,
          'Network:Recognized');
      expect(Statsig.getConfig('no_config').details.reason,
          'Network:Unrecognized');
    });
  });

  group('relaunch with cached values', () {
    test('reports Cache when the network request fails', () async {
      var user = freshUser('cached-user');

      nock('https://featuregates.org')
          .post('/v1/initialize', (body) => true)
          .reply(200, TestData.initializeResponse);
      await Statsig.initialize('a-key', user);

      // Simulate an app relaunch where the network is unavailable.
      Statsig.reset();
      nock('https://featuregates.org')
          .post('/v1/initialize', (body) => true)
          .reply(400, '');
      await Statsig.initialize('a-key', user);

      expect(
          Statsig.getConfig('a_config').details.reason, 'Cache:Recognized');
    });
  });

  group('updateUser to a new user without values', () {
    test('reports Loading immediately after an un-awaited updateUser',
        () async {
      nock('https://featuregates.org')
          .post('/v1/initialize', (body) => true)
          .reply(200, TestData.initializeResponse);
      await Statsig.initialize('a-key', freshUser('pre-switch-user'));

      nock('https://featuregates.org')
          .post('/v1/initialize', (body) => true)
          .reply(400, '');
      // updateUser clears the store synchronously before its first await,
      // so an evaluation in that window must report Loading, never
      // Uninitialized.
      var pending = Statsig.updateUser(freshUser('mid-switch-user'));
      var config = Statsig.getExperiment('an_experiment');
      await pending;

      expect(config.details.reason, 'Loading:Unrecognized');
    });

    test('reports NoValues when the fetch for the new user fails', () async {
      nock('https://featuregates.org')
          .post('/v1/initialize', (body) => true)
          .reply(200, TestData.initializeResponse);
      await Statsig.initialize('a-key', freshUser('first-user'));

      nock('https://featuregates.org')
          .post('/v1/initialize', (body) => true)
          .reply(400, '');
      await Statsig.updateUser(freshUser('second-user'));

      var config = Statsig.getExperiment('an_experiment');
      expect(config.details.reason, 'NoValues');
    });
  });
}
