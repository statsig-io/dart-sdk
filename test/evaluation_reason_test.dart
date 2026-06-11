import 'dart:convert';

import 'package:nock/nock.dart';
import 'package:statsig/src/internal_store.dart';
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

  // The store's save is fire-and-forget, so poll until the user's values are
  // actually on disk before relying on them.
  Future<void> waitForDiskCache(StatsigUser user) async {
    var store = InternalStore();
    for (var i = 0; i < 200; i++) {
      if (await store.readCache(user) != null) {
        return;
      }
      await Future.delayed(Duration(milliseconds: 10));
    }
    fail('cache for ${user.userId} never landed on disk');
  }

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

  group('updateUser to the same user', () {
    // updateUser always resets and reloads, even for the same user, to match
    // the cross-SDK contract (a fresh refetch, not a silent no-op).
    test('reports Loading immediately after an un-awaited updateUser',
        () async {
      var user = freshUser('same-user-loading');
      nock('https://featuregates.org')
          .post('/v1/initialize', (body) => true)
          .reply(200, TestData.initializeResponse);
      await Statsig.initialize('a-key', user);
      expect(Statsig.getConfig('a_config').details.reason, 'Network:Recognized');

      nock('https://featuregates.org')
          .post('/v1/initialize', (body) => true)
          .reply(200, TestData.initializeResponse);
      // Same user, not awaited: the store is reset to Loading synchronously,
      // so an evaluation in that window reports Loading, not the stale value.
      var pending = Statsig.updateUser(user);
      var config = Statsig.getConfig('a_config');
      await pending;

      expect(config.details.reason, 'Loading:Unrecognized');
    });
  });

  group('concurrent updateUser calls', () {
    // These three tests supersede the first updateUser at different points in
    // its lifecycle (during its logger flush, during its cache read, and
    // during its network request) so each early-exit guard is pinned
    // independently. The superseded user always has an on-disk cache, since
    // the contamination is its cache or response leaking into the new user's
    // freshly cleared store.
    test('superseded while flushing must not apply its cache to the new user',
        () async {
      var userA = freshUser('supersede-flush-a');
      var userB = freshUser('supersede-flush-b');

      nock('https://featuregates.org')
          .post('/v1/initialize', (body) => true)
          .reply(200, TestData.initializeResponse);
      await Statsig.initialize('a-key', userA);
      await waitForDiskCache(userA);

      // Both refetches fail.
      nock('https://featuregates.org').post('/v1/initialize', (body) => true)
        ..persist()
        ..reply(400, '');

      // userB's updateUser lands while userA's is still awaiting its logger
      // flush, before userA's fetch has begun.
      var first = Statsig.updateUser(userA);
      var second = Statsig.updateUser(userB);
      await first;
      await second;
      // Give any stray late continuation a chance to do damage.
      await Future.delayed(Duration(milliseconds: 100));

      var config = Statsig.getExperiment('a_config');
      expect(config.details.reason, 'NoValues');
    });

    test('superseded while flushing must not reassign the active user',
        () async {
      var userA = freshUser('supersede-attr-a');
      var userB = freshUser('supersede-attr-b');

      nock('https://featuregates.org')
          .post('/v1/initialize', (body) => true)
          .reply(200, TestData.initializeResponse);
      await Statsig.initialize('a-key', userA);
      await waitForDiskCache(userA);

      nock('https://featuregates.org').post('/v1/initialize', (body) => true)
        ..persist()
        ..reply(400, '');
      var loggedUsers = <String>[];
      nock('https://statsigapi.net').post('/v1/rgstr', (body) {
        for (var event in jsonDecode(utf8.decode(body))['events']) {
          loggedUsers.add('${event['eventName']}:${event['user']['userID']}');
        }
        return true;
      })
        ..persist()
        ..reply(200, '{}', responseDelay: Duration(milliseconds: 100));

      // Make userA's updateUser suspend in a slow event flush, so userB's
      // whole updateUser finishes first. When userA's stale continuation
      // finally resumes it must not set the active user back to userA;
      // otherwise later exposures are attributed to the wrong user.
      Statsig.logEvent('warmup');
      var first = Statsig.updateUser(userA);
      var second = Statsig.updateUser(userB);
      await first;
      await second;

      Statsig.getExperiment('a_config');
      await Statsig.shutdown();

      expect(loggedUsers,
          contains('statsig::config_exposure:${userB.userId}'));
      expect(
          loggedUsers
              .where((u) => u == 'statsig::config_exposure:${userA.userId}'),
          isEmpty);
    });

    test('superseded while reading cache must not apply it to the new user',
        () async {
      var userA = freshUser('supersede-read-a');
      var userB = freshUser('supersede-read-b');

      nock('https://featuregates.org')
          .post('/v1/initialize', (body) => true)
          .reply(200, TestData.initializeResponse);
      await Statsig.initialize('a-key', userA);
      await waitForDiskCache(userA);

      nock('https://featuregates.org').post('/v1/initialize', (body) => true)
        ..persist()
        ..reply(400, '');

      var first = Statsig.updateUser(userA);
      // Yield one event-loop turn: userA's call passes its flush and suspends
      // inside the disk read of its cache, THEN userB's updateUser clears the
      // store. userA's read result must be discarded, not applied.
      await Future.delayed(Duration.zero);
      var second = Statsig.updateUser(userB);
      await first;
      await second;
      await Future.delayed(Duration(milliseconds: 100));

      var config = Statsig.getExperiment('a_config');
      expect(config.details.reason, 'NoValues');
    });

    test('superseded mid-request must not apply its response to the new user',
        () async {
      var userA = freshUser('supersede-net-a');
      var userB = freshUser('supersede-net-b');

      nock('https://featuregates.org')
          .post('/v1/initialize',
              (body) => utf8.decode(body).contains(userA.userId))
          .reply(200, TestData.initializeResponse);
      await Statsig.initialize('a-key', userA);
      await waitForDiskCache(userA);

      // userA's refetch SUCCEEDS but slowly; userB's fails fast.
      nock('https://featuregates.org')
          .post('/v1/initialize',
              (body) => utf8.decode(body).contains(userA.userId))
          .reply(200, TestData.initializeResponse,
              responseDelay: Duration(milliseconds: 100));
      nock('https://featuregates.org')
          .post('/v1/initialize',
              (body) => utf8.decode(body).contains(userB.userId))
          .reply(400, '');

      var first = Statsig.updateUser(userA);
      // Let userA's call get past its cache read and into the network await,
      // then supersede it. Its successful response must be discarded.
      await Future.delayed(Duration(milliseconds: 30));
      var second = Statsig.updateUser(userB);
      await first;
      await second;
      await Future.delayed(Duration(milliseconds: 150));

      var config = Statsig.getExperiment('a_config');
      expect(config.details.reason, 'NoValues');
    });
  });
}
