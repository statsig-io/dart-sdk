import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import 'internal_store.dart';
import 'statsig_event.dart';
import 'statsig_metadata.dart';
import 'statsig_options.dart';
import 'statsig_user.dart';
import 'diagnostics_types.dart';

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
typedef InitializeDiagnostics = void Function(int attempt, bool isStart,
    bool? success, int? statusCode, String? sdkRegion, DiagnosticsError? error);

/// One request chain owns the active attempt and its terminal callback.
class _InitializeRequest {
  final InitializeDiagnostics? _diagnostics;
  final void Function(DiagnosticsError)? _onFailure;
  DiagnosticsError? _error;
  int? _activeAttempt;
  bool completed = false;

  _InitializeRequest(this._diagnostics, this._onFailure);

  void start(int attempt) {
    if (completed) return;
    _activeAttempt = attempt;
    _diagnostics?.call(attempt, true, null, null, null, null);
  }

  void end(bool success, int? statusCode,
      {String? sdkRegion, DiagnosticsError? error}) {
    final attempt = _activeAttempt;
    if (completed || attempt == null) return;
    _activeAttempt = null;
    _error = error;
    _diagnostics?.call(attempt, false, success, statusCode, sdkRegion, error);
  }

  void complete({DiagnosticsError? error}) {
    if (completed) return;
    final terminalError = error ?? _error;
    end(false, null, error: terminalError);
    completed = true;
    if (terminalError != null) _onFailure?.call(terminalError);
  }
}

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

  Future<Map?> initialize(StatsigUser user, InternalStore store,
      {InitializeDiagnostics? diagnostics,
      void Function(DiagnosticsError)? onFailure}) async {
    var url = Uri.parse(_host + '/initialize');
    final request = _InitializeRequest(diagnostics, onFailure);
    try {
      return await _post(
              url,
              {
                "user": user.toJsonWithPrivateAttributes(),
                "statsigMetadata": StatsigMetadata.toJson(),
                "sinceTime": store.getSinceTime(user),
                "previousDerivedFields": store.getPreviousDerivedFields(user),
                "hash": 'djb2',
                "full_checksum": store.getFullChecksum(user),
              },
              3,
              initialBackoffSeconds,
              request)
          .timeout(Duration(seconds: _options.initTimeout), onTimeout: () {
        request.complete(
            error: DiagnosticsError(DiagnosticsErrorName.timeout,
                'Initialize timed out after ${_options.initTimeout} seconds'));
        print("[Statsig]: Initialize timed out.");
        return null;
      });
    } finally {
      request.complete();
    }
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
      [Map? body,
      int retries = 0,
      int backoff = 1,
      _InitializeRequest? request]) async {
    if (request?.completed == true) return null;
    String data = json.encode(body);
    int? statusCode;
    String? sdkRegion;
    try {
      var attempt = 4 - retries;
      request?.start(attempt);
      var headers = {
        ..._headers,
        "STATSIG-CLIENT-TIME": DateTime.now().millisecondsSinceEpoch.toString(),
      };
      var response = await http.post(url, headers: headers, body: data);
      if (request?.completed == true) return null;
      statusCode = response.statusCode;
      sdkRegion = response.headers['x-statsig-region'];

      if (response.statusCode == 204) {
        request?.end(true, statusCode, sdkRegion: sdkRegion);
        return {"has_updates": false};
      }

      if (response.statusCode >= 200 && response.statusCode <= 299) {
        final values = response.bodyBytes.isEmpty
            ? {}
            : jsonDecode(utf8.decode(response.bodyBytes)) as Map;
        request?.end(true, statusCode, sdkRegion: sdkRegion);
        return values;
      } else if (retryCodes.containsKey(response.statusCode) && retries > 0) {
        request?.end(false, statusCode,
            sdkRegion: sdkRegion,
            error: DiagnosticsError(DiagnosticsErrorName.http,
                'Initialize request returned HTTP $statusCode',
                code: '$statusCode'));
        await Future.delayed(Duration(seconds: backoff));
        return await _post(url, body, retries - 1, backoff * 2, request);
      }
      request?.end(false, statusCode,
          sdkRegion: sdkRegion,
          error: DiagnosticsError(DiagnosticsErrorName.http,
              'Initialize request returned HTTP $statusCode',
              code: '$statusCode'));
    } catch (error) {
      request?.end(false, statusCode,
          sdkRegion: sdkRegion, error: _getDiagnosticsError(error));
    }

    return null;
  }

  DiagnosticsError _getDiagnosticsError(Object error) {
    if (error is FormatException) {
      return DiagnosticsError(DiagnosticsErrorName.format, error.message);
    }
    if (error is TypeError) {
      return DiagnosticsError(DiagnosticsErrorName.type, error.toString());
    }
    if (error is http.ClientException) {
      // The public HTTP error message excludes its separate request URI.
      return DiagnosticsError(DiagnosticsErrorName.client, error.message);
    }
    return const DiagnosticsError(
        DiagnosticsErrorName.unknown, 'Initialize request failed');
  }

  @visibleForTesting
  static int initialBackoffSeconds = 1;
}
