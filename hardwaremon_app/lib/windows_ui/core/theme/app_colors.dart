import 'package:flutter/material.dart';

class AppColors {
  static const darkBackground = Color(0xFF050505);
  static const darkBackgroundSecondary = Color(0xFF090909);
  static const darkBackgroundTertiary = Color(0xFF04070D);

  static const lightBackground = Color(0xFFF6F8FB);
  static const lightBackgroundSecondary = Color(0xFFFFFFFF);
  static const lightBackgroundTertiary = Color(0xFFEAF2F8);

  static Color accent = const Color(0xFF0891B2);
  static double sidebarMotionIntensity = 1;

  static const cyan = Colors.cyan;
  static const purple = Colors.purple;
  static const orange = Colors.orange;
  static const red = Colors.redAccent;

  static Color get glow => accent.withValues(alpha: 0.14);

  static void setAccent(Color color) {
    accent = color;
  }

  static void setSidebarMotionIntensity(double value) {
    sidebarMotionIntensity = value.clamp(0, 1.5);
  }

  static bool isLight(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light;
  }

  static Color background(BuildContext context) {
    return isLight(context) ? lightBackground : darkBackground;
  }

  static Color backgroundSecondary(BuildContext context) {
    return isLight(context)
        ? lightBackgroundSecondary
        : darkBackgroundSecondary;
  }

  static Color backgroundTertiary(BuildContext context) {
    return isLight(context) ? lightBackgroundTertiary : darkBackgroundTertiary;
  }

  static Color surface(BuildContext context) {
    return isLight(context) ? const Color(0xEFFFFFFF) : const Color(0xCC111111);
  }

  static Color surfaceElevated(BuildContext context) {
    return isLight(context) ? const Color(0xFFFFFFFF) : const Color(0xDD181818);
  }

  static Color border(BuildContext context) {
    return isLight(context) ? const Color(0x2231495F) : const Color(0x1FFFFFFF);
  }

  static Color textPrimary(BuildContext context) {
    return isLight(context) ? const Color(0xFF111827) : const Color(0xFFF5F5F5);
  }

  static Color textSecondary(BuildContext context) {
    return isLight(context) ? const Color(0xFF607080) : const Color(0xFF9E9E9E);
  }

  static Color textMuted(BuildContext context) {
    return isLight(context) ? const Color(0xFF7A8794) : Colors.white54;
  }

  static Color overlay(BuildContext context, double darkOpacity) {
    return isLight(context)
        ? Colors.black.withValues(alpha: darkOpacity * 0.55)
        : Colors.white.withValues(alpha: darkOpacity);
  }

  static Color shadow(BuildContext context) {
    return isLight(context)
        ? const Color(0x2831495F)
        : Colors.black.withValues(alpha: 0.18);
  }

  static List<Color> pageGradient(BuildContext context) {
    return [
      background(context),
      backgroundSecondary(context),
      backgroundTertiary(context),
    ];
  }
}
