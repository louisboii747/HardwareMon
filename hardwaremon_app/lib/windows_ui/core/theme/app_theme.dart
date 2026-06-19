import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  static SwitchThemeData _switchTheme({
    required Color selectedThumb,
    required Color selectedTrack,
    required Color unselectedThumb,
    required Color unselectedTrack,
    required Color outline,
  }) {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? selectedThumb
            : unselectedThumb;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? selectedTrack
            : unselectedTrack;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? selectedThumb.withValues(alpha: 0.65)
            : outline;
      }),
      trackOutlineWidth: WidgetStateProperty.all(1),
    );
  }

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,

    splashFactory: NoSplash.splashFactory,

    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      surface: Color(0xFF111111),
    ),

    switchTheme: _switchTheme(
      selectedThumb: const Color(0xFFE8FBFF),
      selectedTrack: AppColors.accent.withValues(alpha: 0.6),
      unselectedThumb: const Color(0xFFB9C1CA),
      unselectedTrack: const Color(0xFF252A31),
      outline: const Color(0xFF3A424D),
    ),
  );

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBackground,
    splashFactory: NoSplash.splashFactory,
    colorScheme: const ColorScheme.light(
      primary: AppColors.accent,
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF111827),
    ),
    dropdownMenuTheme: const DropdownMenuThemeData(
      textStyle: TextStyle(color: Color(0xFF111827)),
    ),
    switchTheme: _switchTheme(
      selectedThumb: const Color(0xFFFFFFFF),
      selectedTrack: AppColors.accent.withValues(alpha: 0.72),
      unselectedThumb: const Color(0xFFFFFFFF),
      unselectedTrack: const Color(0xFFD9E2EA),
      outline: const Color(0xFFB8C4CE),
    ),
  );
}
