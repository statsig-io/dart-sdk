import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:statsig/src/statsig_event.dart';
import 'package:statsig/src/statsig_metadata.dart';
import 'package:statsig/statsig.dart';
import 'package:meta/meta.dart';

const defaultHost = 'https://statsigapi.net/v1';

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
  StatsigOptions _options;
  late String _host;
  late Map<String, String> _headers;

  NetworkService(this._options, String sdkKey) {
    _host = _options.api ?? defaultHost;
    _headers = {
      "Content-Type": "application/json",
      "STATSIG-API-KEY": sdkKey,
      "STATSIG-SDK-TYPE": StatsigMetadata.getSDKType(),
      "STATSIG-SDK-VERSION": StatsigMetadata.getSDKVersion()
    };
  }

  Future<Map?> initialize(StatsigUser user) async {
    var url = Uri.parse(_host + '/initialize');
    return await _post(
            url,
            {"user": user, "statsigMetadata": StatsigMetadata.toJson()},
            3,
            initialBackoffSeconds)
        .timeout(Duration(seconds: _options.initTimeout), onTimeout: () {
      print("[Statsig]: Initialize timed out.");
      return null;
    });
  }

  Future<bool> sendEvents(List<StatsigEvent> events) async {
    var url = Uri.parse(_host + '/rgstr');
    var result = await _post(
        url,
        {'events': events, 'statsigMetadata': StatsigMetadata.toJson()},
        2,
        initialBackoffSeconds);
    return result?['success'] ?? false;
  }

  Future<Map?> _post(Uri url,
      [Map? body = null, int retries = 0, int backoff = 1]) async {
    String data = json.encode(body);
    try {
      var response = await http.post(url, headers: _headers, body: data);

      if (response.statusCode == 200) {
        return response.bodyBytes.length == 0
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
