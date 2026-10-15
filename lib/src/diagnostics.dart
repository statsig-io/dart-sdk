import 'dart:convert';
import 'dart:math';

import 'statsig_options.dart';
import 'diagnostics_types.dart';

class Diagnostics {
  static const maxMarkers = 30;
  final DiagnosticsContext context;
  final bool _forceSampling;
  final List<Map<String, dynamic>> markers = [];

  Diagnostics(this.context, StatsigOptions options)
      : _forceSampling = options.forceDiagnosticsSampling;

  void mark(DiagnosticsKey key, DiagnosticsAction action,
      {DiagnosticsStep? step,
      bool? success,
      int? attempt,
      int? statusCode,
      String? sdkRegion,
      DiagnosticsError? error,
      DiagnosticsEvaluationDetails? evaluationDetails}) {
    if (markers.length >= maxMarkers) return;
    markers.add({
      DiagnosticsWire.key: key.wireValue,
      DiagnosticsWire.action: action.wireValue,
      DiagnosticsWire.timestamp: DateTime.now().millisecondsSinceEpoch,
      if (step != null) DiagnosticsWire.step: step.wireValue,
      if (success != null) DiagnosticsWire.success: success,
      if (attempt != null) DiagnosticsWire.attempt: attempt,
      if (statusCode != null) DiagnosticsWire.statusCode: statusCode,
      if (sdkRegion != null) DiagnosticsWire.sdkRegion: sdkRegion,
      if (error != null) DiagnosticsWire.error: error.toJson(),
      if (evaluationDetails != null)
        DiagnosticsWire.evaluationDetails: evaluationDetails.toJson(),
    });
  }

  bool shouldLog(Map? response) {
    if (_forceSampling) return true;
    var rate = response?[DiagnosticsWire.sampling]?[context.wireValue];
    return rate is int && rate > 0 && Random().nextInt(rate) == 0;
  }

  String encodedMarkers() => json.encode(markers);
  void clear() => markers.clear();
}
