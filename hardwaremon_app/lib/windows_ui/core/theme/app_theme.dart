import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: TextStyle(
        color: primary,
        fontSize: 44,
        fontWeight: FontWeight.w700,
        letterSpacing: -2.2,
      ),
      displayMedium: TextStyle(
        color: primary,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.7,
      ),
      headlineLarge: TextStyle(
        color: primary,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.1,
      ),
      headlineMedium: TextStyle(
        color: primary,
        fontSize: 21,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      ),
      titleMedium: TextStyle(
        color: primary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: TextStyle(color: primary, fontSize: 13, height: 1.35),
      bodySmall: TextStyle(color: secondary, fontSize: 11, height: 1.35),
      labelLarge: TextStyle(
        color: primary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.05,
      ),
    );
  }

  static InputDecorationTheme _inputDecoration({
    required Color fill,
    required Color border,
    required Color focus,
  }) {
    OutlineInputBorder outline(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      border: outline(border),
      enabledBorder: outline(border),
      focusedBorder: outline(focus.withValues(alpha: 0.72), 1.2),
      errorBorder: outline(Colors.redAccent.withValues(alpha: 0.65)),
    );
  }

  static ScrollbarThemeData _scrollbarTheme(Color accent) {
    return ScrollbarThemeData(
      thickness: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.hovered) ? 7 : 4,
      ),
      radius: const Radius.circular(12),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => accent.withValues(
          alpha: states.contains(WidgetState.hovered) ? 0.48 : 0.24,
        ),
      ),
      trackColor: const WidgetStatePropertyAll(Colors.transparent),
    );
  }

  static ButtonStyle _buttonStyle(Color accent) {
    return ButtonStyle(
      animationDuration: const Duration(milliseconds: 160),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      overlayColor: WidgetStatePropertyAll(accent.withValues(alpha: 0.08)),
    );
  }

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

  static ThemeData darkTheme(Color accent) => ThemeData(
    brightness: Brightness.dark,
    visualDensity: VisualDensity.compact,
    fontFamilyFallback: const [
      'Inter',
      'Segoe UI Variable',
      'Segoe UI',
      'Noto Sans',
    ],
    scaffoldBackgroundColor: AppColors.darkBackground,
    splashFactory: NoSplash.splashFactory,
    colorScheme: ColorScheme.dark(
      primary: accent,
      secondary: accent,
      surface: const Color(0xFF111111),
    ),
    textTheme: _textTheme(const Color(0xFFF5F7FA), const Color(0xFF9CA3AF)),
    inputDecorationTheme: _inputDecoration(
      fill: const Color(0x99181818),
      border: const Color(0x22FFFFFF),
      focus: accent,
    ),
    scrollbarTheme: _scrollbarTheme(accent),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: const Color(0xF2232323),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0x24FFFFFF)),
      ),
      textStyle: const TextStyle(color: Color(0xFFE5E7EB), fontSize: 10),
      waitDuration: const Duration(milliseconds: 420),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xF5181818),
      elevation: 18,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: const Color(0xF51A1A1A),
      elevation: 16,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xF5202020),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    ),
    filledButtonTheme: FilledButtonThemeData(style: _buttonStyle(accent)),
    elevatedButtonTheme: ElevatedButtonThemeData(style: _buttonStyle(accent)),
    textButtonTheme: TextButtonThemeData(style: _buttonStyle(accent)),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
    switchTheme: _switchTheme(
      selectedThumb: const Color(0xFFE8FBFF),
      selectedTrack: accent.withValues(alpha: 0.6),
      unselectedThumb: const Color(0xFFB9C1CA),
      unselectedTrack: const Color(0xFF252A31),
      outline: const Color(0xFF3A424D),
    ),
  );

  static ThemeData lightTheme(Color accent) => ThemeData(
    brightness: Brightness.light,
    visualDensity: VisualDensity.compact,
    fontFamilyFallback: const [
      'Inter',
      'Segoe UI Variable',
      'Segoe UI',
      'Noto Sans',
    ],
    scaffoldBackgroundColor: AppColors.lightBackground,
    splashFactory: NoSplash.splashFactory,
    colorScheme: ColorScheme.light(
      primary: accent,
      secondary: accent,
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF111827),
    ),
    textTheme: _textTheme(const Color(0xFF111827), const Color(0xFF64748B)),
    inputDecorationTheme: _inputDecoration(
      fill: const Color(0xD9FFFFFF),
      border: const Color(0x2431495F),
      focus: accent,
    ),
    scrollbarTheme: _scrollbarTheme(accent),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: const Color(0xF2FFFFFF),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0x2431495F)),
      ),
      textStyle: const TextStyle(color: Color(0xFF1F2937), fontSize: 10),
      waitDuration: const Duration(milliseconds: 420),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFAFFFFFF),
      elevation: 14,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: const Color(0xFAFFFFFF),
      elevation: 14,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xF21F2937),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    ),
    filledButtonTheme: FilledButtonThemeData(style: _buttonStyle(accent)),
    elevatedButtonTheme: ElevatedButtonThemeData(style: _buttonStyle(accent)),
    textButtonTheme: TextButtonThemeData(style: _buttonStyle(accent)),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
    dropdownMenuTheme: const DropdownMenuThemeData(
      textStyle: TextStyle(color: Color(0xFF111827)),
    ),
    switchTheme: _switchTheme(
      selectedThumb: const Color(0xFFFFFFFF),
      selectedTrack: accent.withValues(alpha: 0.72),
      unselectedThumb: const Color(0xFFFFFFFF),
      unselectedTrack: const Color(0xFFD9E2EA),
      outline: const Color(0xFFB8C4CE),
    ),
  );
}
