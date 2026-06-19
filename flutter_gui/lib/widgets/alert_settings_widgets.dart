import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/alert_service.dart';

class AlertThresholdSlider extends StatefulWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final bool enabled;
  final String enableMessage;
  final ValueChanged<double> onChanged;

  const AlertThresholdSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.enabled,
    required this.enableMessage,
    required this.onChanged,
  });

  @override
  State<AlertThresholdSlider> createState() => _AlertThresholdSliderState();
}

class _AlertThresholdSliderState extends State<AlertThresholdSlider> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  void didUpdateWidget(covariant AlertThresholdSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _value = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayValue = _value == _value.roundToDouble()
        ? _value.toStringAsFixed(0)
        : _value.toStringAsFixed(1);

    return Opacity(
      opacity: widget.enabled ? 1 : 0.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                SizedBox(
                  width: 230,
                  child: Slider(
                    value: _value.clamp(widget.min, widget.max),
                    min: widget.min,
                    max: widget.max,
                    divisions: (widget.max - widget.min).round(),
                    onChanged: widget.enabled
                        ? (value) => setState(() => _value = value)
                        : null,
                    onChangeEnd: widget.enabled ? widget.onChanged : null,
                  ),
                ),
                Container(
                  width: 62,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '$displayValue${widget.unit}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
            if (!widget.enabled)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: colorScheme.onSurface.withValues(alpha: 0.58),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.enableMessage,
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.58),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AlertHistoryPanel extends StatelessWidget {
  final int maxEntries;
  final bool showHeader;

  const AlertHistoryPanel({
    super.key,
    this.maxEntries = 10,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AlertService.instance,
      builder: (context, _) {
        final history = AlertService.instance.history.take(maxEntries).toList();
        final mutedColor = Theme.of(
          context,
        ).colorScheme.onSurface.withValues(alpha: 0.58);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) ...[
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Alert History',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (history.isNotEmpty)
                    TextButton.icon(
                      onPressed: AlertService.instance.clearHistory,
                      icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                      label: const Text('Clear'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ] else if (history.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: AlertService.instance.clearHistory,
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: const Text('Clear'),
                ),
              ),
            if (history.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'No alerts have been recorded.',
                  style: TextStyle(color: mutedColor),
                ),
              )
            else
              ...history.map(
                (event) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${event.metricLabel}: '
                              '${_formatValue(event.value)}${event.unit}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Threshold ${_formatValue(event.threshold)}'
                              '${event.unit}',
                              style: TextStyle(color: mutedColor, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        DateFormat('d MMM, HH:mm').format(event.occurredAt),
                        style: TextStyle(color: mutedColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  static String _formatValue(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }
}
