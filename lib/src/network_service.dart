import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:statsig/src/statsig_event.dart';
import 'package:statsig/statsig.dart';

const key = 'client-vklyTVG7MNvuUw2hhGYPYu8ZdlzD1yGsnwGuafbGiuQ';
const defaultHost = 'https://api.statsig.com/v1';
const statsigMeta = {"sdkType": "dart", "sdkVersion": "1.0.0"};

class NetworkService {
  late String _host;

  NetworkService(StatsigOptions options) {
    _host = options.api ?? defaultHost;
  }

  Future<Map> initialize(StatsigUser user) async {
    var url = Uri.parse(_host + '/initialize');
    var response =
        await _post(url, {"user": user, "statsigMetadata": statsigMeta});
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map;
  }

  Future<void> sendEvents(List<StatsigEvent> events) async {
    var url = Uri.parse(_host + '/rgstr');
    await _post(url, {'events': events, 'statsigMetadata': statsigMeta});
  }

  Future<http.Response> _post(Uri url, [Map? body = null]) async {
    String data = json.encode(body);
    return await http.post(url,
        headers: {"content-type": "application/json"}, body: data);
  }
}
