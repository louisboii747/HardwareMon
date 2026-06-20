import 'package:flutter/material.dart';

import '../models/telemetry_sample.dart';

typedef TelemetrySeriesBuilder =
    Widget Function(BuildContext context, List<TelemetrySample> samples);

class SmoothTelemetrySeries extends StatefulWidget {
  final List<TelemetrySample> samples;
  final Duration duration;
  final Curve curve;
  final TelemetrySeriesBuilder builder;

  const SmoothTelemetrySeries({
    super.key,
    required this.samples,
    required this.builder,
    this.duration = const Duration(milliseconds: 700),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<SmoothTelemetrySeries> createState() => _SmoothTelemetrySeriesState();
}

class _SmoothTelemetrySeriesState extends State<SmoothTelemetrySeries>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<TelemetrySample> _from;
  late List<TelemetrySample> _to;

  @override
  void initState() {
    super.initState();
    _from = List<TelemetrySample>.of(widget.samples);
    _to = List<TelemetrySample>.of(widget.samples);
    _controller = AnimationController(vsync: this, value: 1);
  }

  @override
  void didUpdateWidget(covariant SmoothTelemetrySeries oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_seriesMatches(_to, widget.samples)) {
      return;
    }

    final current = _interpolatedSamples(_controller.value);
    _to = List<TelemetrySample>.of(widget.samples);
    _from = _normaliseSource(current, _to.length);

    if (widget.duration == Duration.zero || _to.isEmpty) {
      _from = List<TelemetrySample>.of(_to);
      _controller.value = 1;
      return;
    }

    _controller.duration = widget.duration;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _seriesMatches(
    List<TelemetrySample> current,
    List<TelemetrySample> incoming,
  ) {
    if (current.length != incoming.length) return false;
    if (current.isEmpty) return true;

    final currentFirst = current.first;
    final incomingFirst = incoming.first;
    final currentLast = current.last;
    final incomingLast = incoming.last;
    return currentFirst.timestamp == incomingFirst.timestamp &&
        currentFirst.value == incomingFirst.value &&
        currentLast.timestamp == incomingLast.timestamp &&
        currentLast.value == incomingLast.value;
  }

  List<TelemetrySample> _normaliseSource(
    List<TelemetrySample> source,
    int targetLength,
  ) {
    if (targetLength == 0) return const [];
    if (source.isEmpty) {
      return List<TelemetrySample>.filled(targetLength, _to.first);
    }
    if (source.length > targetLength) {
      return source.sublist(source.length - targetLength);
    }
    if (source.length == targetLength) {
      return List<TelemetrySample>.of(source);
    }

    return [
      ...source,
      ...List<TelemetrySample>.filled(
        targetLength - source.length,
        source.last,
      ),
    ];
  }

  List<TelemetrySample> _interpolatedSamples(double animationValue) {
    if (_to.isEmpty) return const [];

    final easedValue = widget.curve.transform(animationValue);
    final from = _normaliseSource(_from, _to.length);

    return List<TelemetrySample>.generate(_to.length, (index) {
      final start = from[index];
      final end = _to[index];
      final startMicros = start.timestamp.microsecondsSinceEpoch;
      final endMicros = end.timestamp.microsecondsSinceEpoch;
      final timestampMicros =
          startMicros + ((endMicros - startMicros) * easedValue).round();

      return TelemetrySample(
        timestamp: DateTime.fromMicrosecondsSinceEpoch(timestampMicros),
        value: start.value + ((end.value - start.value) * easedValue),
      );
    }, growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return widget.builder(context, _interpolatedSamples(_controller.value));
      },
    );
  }
}
