import 'package:flutter/material.dart';

class AppColors {
  static const darkBackground = Color(0xFF171A1D);
  static const darkBackgroundSecondary = Color(0xFF1D2226);
  static const darkBackgroundTertiary = Color(0xFF232A2F);

  static const lightBackground = Color(0xFFE8E3D8);
  static const lightBackgroundSecondary = Color(0xFFF0ECE3);
  static const lightBackgroundTertiary = Color(0xFFDDD9CF);

  static const workOrderBlue = Color.from(
    alpha: 1,
    red: 0.145,
    green: 0.369,
    blue: 0.522,
  );
  static const warningRed = Color(0xFFB5483B);
  static const healthyGreen = Color(0xFF39764B);
  static const binderRail = Color(0xFF303941);
  static const binderRailDark = Color(0xFF222A30);
  static const ink = Color(0xFF1C252B);

  static Color accent = workOrderBlue;
  static double sidebarMotionIntensity = 1;

  static const cyan = Colors.cyan;
  static const purple = Colors.purple;
  static const orange = Colors.orange;
  static const red = Colors.redAccent;

  static Color get glow => accent.withValues(alpha: 0.06);

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
    return isLight(context)
        ? lightBackgroundSecondary
        : darkBackgroundSecondary;
  }

  static Color surfaceElevated(BuildContext context) {
    return isLight(context) ? const Color(0xFFF7F3EA) : darkBackgroundTertiary;
  }

  static Color border(BuildContext context) {
    return isLight(context) ? const Color(0xFFBEC3C2) : const Color(0xFF465159);
  }

  static Color textPrimary(BuildContext context) {
    return isLight(context) ? ink : const Color(0xFFF0F1ED);
  }

  static Color textSecondary(BuildContext context) {
    return isLight(context) ? const Color(0xFF43525B) : const Color(0xFFC1C8C7);
  }

  static Color textMuted(BuildContext context) {
    return isLight(context) ? const Color(0xFF657177) : const Color(0xFF929D9F);
  }

  static Color overlay(BuildContext context, double darkOpacity) {
    return isLight(context)
        ? Colors.black.withValues(alpha: darkOpacity * 0.55)
        : Colors.white.withValues(alpha: darkOpacity);
  }

  static Color shadow(BuildContext context) {
    return isLight(context)
        ? const Color(0x26262A2C)
        : Colors.black.withValues(alpha: 0.28);
  }

  static Color frame(BuildContext context) {
    return isLight(context) ? const Color(0xFF15191C) : const Color(0xFF0E1113);
  }

  static Color rail(BuildContext context) {
    return isLight(context) ? binderRail : binderRailDark;
  }

  static Color rule(BuildContext context) {
    return isLight(context) ? const Color(0xFFB7BEBD) : const Color(0xFF465159);
  }

  static Color controlFill(BuildContext context) {
    return isLight(context) ? const Color(0xFFE2DED5) : const Color(0xFF272E33);
  }

  static List<Color> pageGradient(BuildContext context) {
    final color = background(context);
    return [color, color, color];
  }
}
