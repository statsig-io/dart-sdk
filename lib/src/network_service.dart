import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import 'internal_store.dart';
import 'statsig_event.dart';
import 'statsig_metadata.dart';
import 'statsig_options.dart';
import 'statsig_user.dart';

const defaultLoggingHost = 'https://statsigapi.net/v1';
const defaultHost = 'https://featuregates.org/v1';

const retryCodes = {
  408: true,
  500: true,
  502: true,
  503: true,
  504: true,
  522: true,
  524: true,
  599: true,
};

class NetworkService {
  final StatsigOptions _options;
  late String _host;
  late String _loggingHost;
  late Map<String, String> _headers;

  NetworkService(this._options, String sdkKey) {
    _host = _options.api ?? defaultHost;
    _loggingHost = _options.api ?? defaultLoggingHost;
    _headers = {
      "Content-Type": "application/json",
      "STATSIG-API-KEY": sdkKey,
      "STATSIG-SDK-TYPE": StatsigMetadata.getSDKType(),
      "STATSIG-SDK-VERSION": StatsigMetadata.getSDKVersion(),
    };
  }

  Future<Map?> initialize(StatsigUser user, InternalStore store) async {
    var url = Uri.parse(_host + '/initialize');
    return await _post(
            url,
            {
              "user": user.toJsonWithPrivateAttributes(),
              "statsigMetadata": StatsigMetadata.toJson(),
              "sinceTime": store.getSinceTime(user),
              "previousDerivedFields": store.getPreviousDerivedFields(user),
              "hash": 'djb2',
            },
            3,
            initialBackoffSeconds)
        .timeout(Duration(seconds: _options.initTimeout), onTimeout: () {
      print("[Statsig]: Initialize timed out.");
      return null;
    });
  }

  Future<bool> sendEvents(List<StatsigEvent> events) async {
    var url = Uri.parse(_loggingHost + '/rgstr');
    var result = await _post(
        url,
        {'events': events, 'statsigMetadata': StatsigMetadata.toJson()},
        2,
        initialBackoffSeconds);
    return result?['success'] ?? false;
  }

  Future<Map?> _post(Uri url,
      [Map? body, int retries = 0, int backoff = 1]) async {
    String data = json.encode(body);
    try {
      var headers = {
        ..._headers,
        "STATSIG-CLIENT-TIME": DateTime.now().millisecondsSinceEpoch.toString(),
      };
      var response = await http.post(url, headers: headers, body: data);

      if (response.statusCode >= 200 && response.statusCode <= 299) {
        return response.bodyBytes.isEmpty
            ? {}
            : jsonDecode(utf8.decode(response.bodyBytes)) as Map;
      } else if (retryCodes.containsKey(response.statusCode) && retries > 0) {
        await Future.delayed(Duration(seconds: backoff));
        return await _post(url, body, retries - 1, backoff * 2);
      }
    } catch (_) {}

    return null;
  }

  @visibleForTesting
  static int initialBackoffSeconds = 1;
}
