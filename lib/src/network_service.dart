import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:statsig/src/statsig_event.dart';
import 'package:statsig/statsig.dart';

const defaultHost = 'https://statsigapi.net/v1';
const statsigMeta = {"sdkType": "dart", "sdkVersion": "1.0.0"};

class NetworkService {
  late String _host;

  NetworkService(StatsigOptions options) {
    _host = options.api ?? defaultHost;
  }

  Future<Map?> initialize(StatsigUser user) async {
    var url = Uri.parse(_host + '/initialize');
    return await _post(url, {"user": user, "statsigMetadata": statsigMeta}, 3);
  }

  Future<void> sendEvents(List<StatsigEvent> events) async {
    var url = Uri.parse(_host + '/rgstr');
    await _post(url, {'events': events, 'statsigMetadata': statsigMeta});
  }

  Future<Map?> _post(Uri url,
      [Map? body = null, int retries = 0, int backoff = 1000]) async {
    String data = json.encode(body);
    try {
      var response = await http.post(url,
          headers: {
            "Content-Type": "application/json",
            "STATSIG-SDK-TYPE": statsigMeta['sdkType'] ?? '',
            "STATSIG-SDK-VERSION": statsigMeta['sdkVersion'] ?? ""
          },
          body: data);
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map;
    } catch (_) {
      if (retries > 0) {
        await Future.delayed(Duration(milliseconds: backoff));
        return await _post(url, body, retries - 1, backoff * 2);
      }
      return null;
    }
  }
}
