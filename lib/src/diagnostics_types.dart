import 'package:meta/meta.dart';

/// Internal diagnostics vocabulary. Wire values are independent of Dart names.
@internal
enum DiagnosticsContext {
  initialize('initialize'),
  updateUser('update_user');

  const DiagnosticsContext(this.wireValue);
  final String wireValue;
}

@internal
enum DiagnosticsKey {
  overall('overall'),
  initialize('initialize');

  const DiagnosticsKey(this.wireValue);
  final String wireValue;
}

@internal
enum DiagnosticsStep {
  loadCache('load_cache'),
  networkRequest('network_request'),
  process('process');

  const DiagnosticsStep(this.wireValue);
  final String wireValue;
}

@internal
enum DiagnosticsAction {
  start('start'),
  end('end');

  const DiagnosticsAction(this.wireValue);
  final String wireValue;
}

@internal
enum DiagnosticsErrorName {
  http('HttpError'),
  timeout('TimeoutError'),
  format('FormatException'),
  type('TypeError'),
  client('ClientException'),
  socket('SocketException'),
  sdkKeyMismatch('SDKKeyMismatch'),
  unknown('Error');

  const DiagnosticsErrorName(this.wireValue);
  final String wireValue;
}

@internal
enum DiagnosticsEvaluationReason {
  loading('Loading'),
  networkNotModified('NetworkNotModified'),
  network('Network'),
  cache('Cache'),
  uninitialized('Uninitialized'),
  noValues('NoValues');

  const DiagnosticsEvaluationReason(this.wireValue);
  final String wireValue;
}

@internal
class DiagnosticsError {
  final DiagnosticsErrorName name;
  final String message;
  final String? code;

  const DiagnosticsError(this.name, this.message, {this.code});

  Map<String, dynamic> toJson() => {
        DiagnosticsWire.name: name.wireValue,
        DiagnosticsWire.message: message,
        if (code != null) DiagnosticsWire.code: code,
      };
}

/// An immutable snapshot of the values source at operation completion.
@internal
class DiagnosticsEvaluationDetails {
  final DiagnosticsEvaluationReason reason;
  final int lcut;
  final int receivedAt;

  const DiagnosticsEvaluationDetails(this.reason, this.lcut, this.receivedAt);

  Map<String, dynamic> toJson() => {
        DiagnosticsWire.reason: reason.wireValue,
        if (reason != DiagnosticsEvaluationReason.noValues &&
            reason != DiagnosticsEvaluationReason.uninitialized) ...{
          DiagnosticsWire.lcut: lcut,
          DiagnosticsWire.receivedAt: receivedAt,
        },
      };
}

@internal
abstract class DiagnosticsWire {
  static const eventName = 'statsig::diagnostics';
  static const sampling = 'diagnostics';
  static const context = 'context';
  static const markers = 'markers';
  static const key = 'key';
  static const action = 'action';
  static const timestamp = 'timestamp';
  static const step = 'step';
  static const success = 'success';
  static const attempt = 'attempt';
  static const statusCode = 'statusCode';
  static const error = 'error';
  static const sdkRegion = 'sdkRegion';
  static const evaluationDetails = 'evaluationDetails';
  static const reason = 'reason';
  static const lcut = 'lcut';
  static const receivedAt = 'receivedAt';
  static const name = 'name';
  static const message = 'message';
  static const code = 'code';
}
