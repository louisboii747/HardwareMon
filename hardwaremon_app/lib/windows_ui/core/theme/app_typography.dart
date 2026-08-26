import 'package:flutter/material.dart';

class AppTypography {
  static const displayFamily = 'Barlow Condensed';
  static const bodyFamily = 'Atkinson Hyperlegible';
  static const metricFamily = 'JetBrains Mono';

  static const display = TextStyle(
    fontFamily: displayFamily,
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    height: 1,
  );

  static const heading = TextStyle(
    fontFamily: displayFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.1,
  );

  static const body = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const metric = TextStyle(
    fontFamily: metricFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const sectionLabel = TextStyle(
    fontFamily: displayFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.7,
    height: 1,
  );

  static const metadata = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.25,
  );
}
