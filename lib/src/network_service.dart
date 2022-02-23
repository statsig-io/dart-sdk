import 'dart:convert';
import 'package:http/http.dart' as http;

const key = 'client-vklyTVG7MNvuUw2hhGYPYu8ZdlzD1yGsnwGuafbGiuQ';
const host = 'https://api.statsig.com';

class NetworkService {
  Future<Map> initialize() async {
    var url = Uri.parse(host + '/v1/initialize');
    var response = await http.post(url);
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map;
  }
}
