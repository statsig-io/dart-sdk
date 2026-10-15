import 'dart:convert';

import 'package:statsig/src/diagnostics.dart';
import 'package:statsig/src/diagnostics_types.dart';
import 'package:statsig/src/statsig_event.dart';
import 'package:statsig/src/statsig_options.dart';
import 'package:test/test.dart';

void main() {
  test('every diagnostics enum has an explicit stable wire mapping', () {
    expect(DiagnosticsContext.values.map((value) => value.wireValue),
        ['initialize', 'update_user']);
    expect(DiagnosticsKey.values.map((value) => value.wireValue),
        ['overall', 'initialize']);
    expect(DiagnosticsAction.values.map((value) => value.wireValue),
        ['start', 'end']);
    expect(DiagnosticsStep.values.map((value) => value.wireValue),
        ['load_cache', 'network_request', 'process']);
    expect(DiagnosticsErrorName.values.map((value) => value.wireValue), [
      'HttpError',
      'TimeoutError',
      'FormatException',
      'TypeError',
      'ClientException',
      'SocketException',
      'SDKKeyMismatch',
      'Error',
    ]);
    expect(DiagnosticsEvaluationReason.values.map((value) => value.wireValue), [
      'Loading',
      'NetworkNotModified',
      'Network',
      'Cache',
      'Uninitialized',
      'NoValues',
    ]);
  });

  test('diagnostics field and event names preserve the wire contract', () {
    expect([
      DiagnosticsWire.eventName,
      DiagnosticsWire.sampling,
      DiagnosticsWire.context,
      DiagnosticsWire.markers,
      DiagnosticsWire.key,
      DiagnosticsWire.action,
      DiagnosticsWire.timestamp,
      DiagnosticsWire.step,
      DiagnosticsWire.success,
      DiagnosticsWire.attempt,
      DiagnosticsWire.statusCode,
      DiagnosticsWire.error,
      DiagnosticsWire.sdkRegion,
      DiagnosticsWire.evaluationDetails,
      DiagnosticsWire.reason,
      DiagnosticsWire.lcut,
      DiagnosticsWire.receivedAt,
      DiagnosticsWire.name,
      DiagnosticsWire.message,
      DiagnosticsWire.code,
    ], [
      'statsig::diagnostics',
      'diagnostics',
      'context',
      'markers',
      'key',
      'action',
      'timestamp',
      'step',
      'success',
      'attempt',
      'statusCode',
      'error',
      'sdkRegion',
      'evaluationDetails',
      'reason',
      'lcut',
      'receivedAt',
      'name',
      'message',
      'code',
    ]);
  });

  for (final context in DiagnosticsContext.values) {
    test('serializes complete ${context.wireValue} event with string markers',
        () {
      final diagnostics = Diagnostics(context, StatsigOptions());
      diagnostics.mark(DiagnosticsKey.overall, DiagnosticsAction.start);
      for (final step in DiagnosticsStep.values) {
        diagnostics.mark(DiagnosticsKey.initialize, DiagnosticsAction.end,
            step: step,
            success: false,
            attempt: 1,
            statusCode: 566,
            sdkRegion: 'test-region',
            error: const DiagnosticsError(
                DiagnosticsErrorName.http, 'wire error', code: '566'),
            evaluationDetails: const DiagnosticsEvaluationDetails(
                DiagnosticsEvaluationReason.cache, 12, 34));
      }
      final event = jsonDecode(jsonEncode(
          StatsigEvent.createDiagnostics(context, diagnostics.markers)
              .toJson()));
      expect(event.keys.toSet(), {'eventName', 'user', 'time', 'metadata'});
      expect(event['eventName'], 'statsig::diagnostics');
      expect(event['user'], isNull);
      expect(event['time'], isA<int>());
      expect(event['metadata'].keys.toSet(), {'context', 'markers'});
      expect(
          event['metadata']['context'],
          context == DiagnosticsContext.initialize
              ? 'initialize'
              : 'update_user');
      expect(event['metadata']['markers'], isA<String>());
      expect(event['metadata']['markers'], diagnostics.encodedMarkers());
      final markers = jsonDecode(event['metadata']['markers']) as List;
      for (final marker in markers) {
        expect(marker.remove('timestamp'), isA<int>());
      }
      expect(markers, [
        {'key': 'overall', 'action': 'start'},
        for (final step in ['load_cache', 'network_request', 'process'])
          {
            'key': 'initialize',
            'action': 'end',
            'step': step,
            'success': false,
            'attempt': 1,
            'statusCode': 566,
            'sdkRegion': 'test-region',
            'error': {
              'name': 'HttpError',
              'message': 'wire error',
              'code': '566'
            },
            'evaluationDetails': {
              'reason': 'Cache',
              'lcut': 12,
              'receivedAt': 34
            },
          },
      ]);
    });

    test('sampling uses ${context.wireValue} wire key', () {
      final diagnostics = Diagnostics(context, StatsigOptions());
      expect(
          diagnostics.shouldLog({
            'diagnostics': {
              'initialize': context == DiagnosticsContext.initialize ? 1 : 0,
              'update_user': context == DiagnosticsContext.updateUser ? 1 : 0,
            }
          }),
          isTrue);
      expect(
          diagnostics.shouldLog({
            'diagnostics': {
              'initialize': context == DiagnosticsContext.initialize ? 0 : 1,
              'update_user': context == DiagnosticsContext.updateUser ? 0 : 1,
            }
          }),
          isFalse);
    });
  }

  test('value-less snapshots omit times and structured errors omit null codes',
      () {
    expect(
        const DiagnosticsEvaluationDetails(
                DiagnosticsEvaluationReason.noValues, 0, 0)
            .toJson(),
        {'reason': 'NoValues'});
    expect(
        const DiagnosticsEvaluationDetails(
                DiagnosticsEvaluationReason.uninitialized, 0, 0)
            .toJson(),
        {'reason': 'Uninitialized'});
    expect(
        const DiagnosticsError(DiagnosticsErrorName.timeout, 'timed out')
            .toJson(),
        {'name': 'TimeoutError', 'message': 'timed out'});
  });

  test('null failures remain unsampled unless explicitly forced', () {
    for (final context in DiagnosticsContext.values) {
      expect(Diagnostics(context, StatsigOptions()).shouldLog(null), isFalse);
      expect(
          Diagnostics(context, StatsigOptions(forceDiagnosticsSampling: true))
              .shouldLog(null),
          isTrue);
    }
  });
}
