@Timeout(Duration(seconds: 1))
import 'package:nock/nock.dart';
import 'package:statsig/src/disk_util/disk_util.dart';
import 'package:statsig/statsig.dart';
import 'package:test/test.dart';

import 'test_data.dart';

void main() {
  final Matcher isUuid = matches(
    RegExp(
      r'^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-4[0-9A-Fa-f]{3}-[89ABab][0-9A-Fa-f]{3}-[0-9A-Fa-f]{12}$',
      caseSensitive: false,
      multiLine: false,
    ),
  );

  group('Stable ID', () {
    setUpAll(() {
      nock.init();
    });

    setUp(() {
      Statsig.reset();
      nock.cleanAll();

      nock('https://statsigapi.net')
          .post('/v1/initialize', (body) => true)
          .reply(200, TestData.initializeResponse);
    });

    group("auto generated stable id", () {
      test('a new uuid is generated', () async {
        String? original =
            await DiskUtil.instance.read("statsig_stable_id", destroyAfterReading: true);
        await Statsig.initialize('a-key');
        String? current = await DiskUtil.instance.read("statsig_stable_id");
        expect(current, isNot(original));
        expect(current, isUuid);
      });

      test('persisting the override', () async {
        String? original = await DiskUtil.instance.read("statsig_stable_id");
        await Statsig.initialize('a-key');
        String? current = await DiskUtil.instance.read("statsig_stable_id");

        expect(current, original);
      });
    });

    group("overriding stable id", () {
      setUp(() async {
        await DiskUtil.instance.read("statsig_stable_id", destroyAfterReading: true);
        await Statsig.initialize(
            'a-key', null, StatsigOptions(overrideStableID: "my_custom_id"));

        var end = DateTime.now().add(Duration(milliseconds: 100));
        while ((await DiskUtil.instance.read("statsig_stable_id")).isEmpty && DateTime.now().isBefore(end)) { }
      });

      test('saves override to disk', () async {
        String? current = await DiskUtil.instance.read("statsig_stable_id");
        expect(current, "my_custom_id");
      });

      test('persisting the override', () async {
        await Statsig.initialize('a-key');

        String? current = await DiskUtil.instance.read("statsig_stable_id");
        expect(current, "my_custom_id");
      });
    });
  });
}
