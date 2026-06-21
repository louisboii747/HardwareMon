import 'dart:math' as math;

import 'package:intl/intl.dart';

import '../models/telemetry_sample.dart';

enum TelemetryTimeRange {
  last5Minutes('Last 5 minutes', Duration(minutes: 5)),
  last30Minutes('Last 30 minutes', Duration(minutes: 30)),
  last1Hour('Last 1 hour', Duration(hours: 1)),
  last24Hours('Last 24 hours', Duration(hours: 24)),
  last7Days('Last 7 days', Duration(days: 7)),
  last30Days('Last 30 days', Duration(days: 30));

  const TelemetryTimeRange(this.label, this.duration);

  final String label;
  final Duration duration;
}

class TimeAxisTick {
  final double x;
  final DateTime timestamp;
  final String label;

  const TimeAxisTick({
    required this.x,
    required this.timestamp,
    required this.label,
  });
}

class TimeAxisScale {
  final DateTime start;
  final DateTime end;
  final Duration visibleRange;
  final double maxX;
  final double tickInterval;
  final List<TimeAxisTick> ticks;

  const TimeAxisScale({
    required this.start,
    required this.end,
    required this.visibleRange,
    required this.maxX,
    required this.tickInterval,
    required this.ticks,
  });

  double xFor(DateTime timestamp) {
    if (maxX <= 0) return 0;
    return timestamp
        .difference(start)
        .inMilliseconds
        .toDouble()
        .clamp(0, maxX)
        .toDouble();
  }

  TimeAxisTick? tickNear(double value) {
    if (ticks.isEmpty) return null;

    final tolerance = math.max(0.5, tickInterval.abs() * 0.02);
    TimeAxisTick? closest;
    var closestDistance = double.infinity;

    for (final tick in ticks) {
      final distance = (tick.x - value).abs();
      if (distance < closestDistance) {
        closestDistance = distance;
        closest = tick;
      }
    }

    return closestDistance <= tolerance ? closest : null;
  }
}

int adaptiveTimeLabelCount(
  double width, {
  double minimumSpacing = 92,
  int minimum = 2,
  int maximum = 10,
}) {
  if (!width.isFinite || width <= 0) return minimum;

  final count = (width / minimumSpacing).floor() + 1;
  return count.clamp(minimum, maximum);
}

String formatTimeAxisTimestamp(DateTime timestamp, Duration visibleRange) {
  if (visibleRange.inMilliseconds <= const Duration(days: 1).inMilliseconds) {
    return DateFormat('HH:mm').format(timestamp);
  }

  if (visibleRange < const Duration(days: 7)) {
    return DateFormat('EEE HH:mm').format(timestamp);
  }

  return DateFormat('dd MMM').format(timestamp);
}

String formatTelemetryTooltipTimestamp(DateTime timestamp) {
  return DateFormat('EEE, dd MMM • HH:mm:ss').format(timestamp);
}

TimeAxisScale generateTimeAxisTicks({
  required List<TelemetrySample> samples,
  required double width,
  double density = 1,
}) {
  final now = DateTime.now();
  final ordered = samples.toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  final start = ordered.isEmpty ? now : ordered.first.timestamp;
  final dataEnd = ordered.isEmpty ? now : ordered.last.timestamp;
  final rawRange = dataEnd.difference(start);
  final hasRange = rawRange.inMilliseconds > 0;
  final visibleRange = hasRange ? rawRange : const Duration(minutes: 1);
  final maxX = visibleRange.inMilliseconds.toDouble();
  final tickCount = hasRange
      ? adaptiveTimeLabelCount(width * density.clamp(0.55, 1.8))
      : 1;
  final tickInterval = tickCount > 1 ? maxX / (tickCount - 1) : maxX;

  final ticks = List<TimeAxisTick>.generate(tickCount, (index) {
    final ratio = tickCount == 1 ? 0.0 : index / (tickCount - 1);
    final offset = (visibleRange.inMilliseconds * ratio).round();
    final timestamp = start.add(Duration(milliseconds: offset));

    return TimeAxisTick(
      x: tickCount == 1 ? 0 : tickInterval * index,
      timestamp: timestamp,
      label: formatTimeAxisTimestamp(timestamp, visibleRange),
    );
  });

  return TimeAxisScale(
    start: start,
    end: start.add(visibleRange),
    visibleRange: visibleRange,
    maxX: maxX,
    tickInterval: tickInterval,
    ticks: ticks,
  );
}

List<TelemetrySample> samplesWithinRange(
  List<TelemetrySample> samples,
  TelemetryTimeRange range, {
  DateTime? end,
}) {
  if (samples.isEmpty) return const [];

  final rangeEnd = end ?? samples.last.timestamp;
  final rangeStart = rangeEnd.subtract(range.duration);

  return samples
      .where(
        (sample) =>
            !sample.timestamp.isBefore(rangeStart) &&
            !sample.timestamp.isAfter(rangeEnd),
      )
      .toList(growable: false);
}
