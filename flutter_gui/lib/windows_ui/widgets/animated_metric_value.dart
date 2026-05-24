import 'package:flutter/material.dart';

class AnimatedMetricValue extends StatelessWidget {
  final double value;
  final bool isTemperature;

  const AnimatedMetricValue({
    super.key,
    required this.value,
    this.isTemperature = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = value.toStringAsFixed(0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,

      children: [
        ...displayValue.split('').map((digit) {
          return SizedBox(
            width: 34,
            height: 64,

            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (child, animation) {
                return ClipRect(
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 1),
                      end: Offset.zero,
                    ).animate(animation),

                    child: FadeTransition(opacity: animation, child: child),
                  ),
                );
              },

              child: Text(
                digit,
                key: ValueKey('${digit}_${value.toStringAsFixed(0)}'),

                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -3,
                ),
              ),
            ),
          );
        }),

        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 4),

          child: Text(
            isTemperature ? '°C' : '%',

            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }
}
