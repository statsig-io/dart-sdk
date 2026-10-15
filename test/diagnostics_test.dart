import 'package:statsig/src/diagnostics.dart';
import 'package:statsig/src/diagnostics_types.dart';
import 'package:statsig/src/statsig_options.dart';
import 'package:test/test.dart';

void main() {
  test('caps diagnostic markers and records lifecycle metadata', () {
    var diagnostics =
        Diagnostics(DiagnosticsContext.initialize, StatsigOptions());
    for (var i = 0; i < 40; i++) {
      diagnostics.mark(DiagnosticsKey.overall, DiagnosticsAction.start);
    }
    expect(diagnostics.markers, hasLength(30));
    var marker = diagnostics.markers.first;
    expect(marker['timestamp'], greaterThan(0));
    diagnostics.clear();
    expect(diagnostics.markers, isEmpty);
  });
}
