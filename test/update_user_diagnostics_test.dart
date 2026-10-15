import 'package:test/test.dart';
import 'package:statsig/src/diagnostics.dart';
import 'package:statsig/src/diagnostics_types.dart';
import 'package:statsig/src/statsig_options.dart';

void main() {
  test('update user context has independent markers with Android keys', () {
    var diagnostics =
        Diagnostics(DiagnosticsContext.updateUser, StatsigOptions());
    diagnostics.mark(DiagnosticsKey.overall, DiagnosticsAction.start);
    diagnostics.mark(DiagnosticsKey.initialize, DiagnosticsAction.start,
        step: DiagnosticsStep.networkRequest, attempt: 1);
    diagnostics.mark(DiagnosticsKey.initialize, DiagnosticsAction.end,
        step: DiagnosticsStep.networkRequest,
        attempt: 1,
        success: true,
        statusCode: 200);
    diagnostics.mark(DiagnosticsKey.overall, DiagnosticsAction.end,
        success: true);
    expect(diagnostics.markers.map((m) => m['key']),
        ['overall', 'initialize', 'initialize', 'overall']);
    expect(
        diagnostics.markers.where((m) => m['step'] == 'load_cache'), isEmpty);
  });
}
