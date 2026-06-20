import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gui/windows_ui/models/telemetry_sample.dart';
import 'package:flutter_gui/windows_ui/widgets/smooth_telemetry_series.dart';

void main() {
  testWidgets('new telemetry samples interpolate instead of snapping', (
    tester,
  ) async {
    final start = DateTime(2026, 6, 20, 12);
    var renderedValue = 0.0;

    Widget buildSeries(List<TelemetrySample> samples) {
      return MaterialApp(
        home: SmoothTelemetrySeries(
          samples: samples,
          duration: const Duration(milliseconds: 700),
          curve: Curves.linear,
          builder: (context, animatedSamples) {
            renderedValue = animatedSamples.last.value;
            return const SizedBox();
          },
        ),
      );
    }

    await tester.pumpWidget(
      buildSeries([TelemetrySample(timestamp: start, value: 10)]),
    );
    expect(renderedValue, 10);

    await tester.pumpWidget(
      buildSeries([
        TelemetrySample(timestamp: start, value: 10),
        TelemetrySample(
          timestamp: start.add(const Duration(seconds: 1)),
          value: 90,
        ),
      ]),
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(renderedValue, greaterThan(10));
    expect(renderedValue, lessThan(90));

    await tester.pump(const Duration(milliseconds: 350));
    expect(renderedValue, closeTo(90, 0.001));
  });
}
