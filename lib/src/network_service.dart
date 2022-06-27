import 'dart:convert';

import 'package:http/http.dart' as http;

const key = 'client-vklyTVG7MNvuUw2hhGYPYu8ZdlzD1yGsnwGuafbGiuQ';
const host = 'https://api.statsig.com';
const statsigMeta = {"sdkType": "dart", "sdkVersion": "1.0.0"};

class NetworkService {
  Future<Map> initialize() async {
    var url = Uri.parse(host + '/v1/initialize');
    var response = await http.post(url);
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map;
  }

  Future<void> sendEvents(List events) async {
    var url = Uri.parse(host + '/v1/rgstr');
    Map data = {'events': events, 'statsigMetadata': statsigMeta};
    String body = json.encode(data);
    await http.post(url, body: body);
  }
}
