import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: AppTypography.display.copyWith(
        color: primary,
        fontSize: 40,
      ),
      displayMedium: AppTypography.display.copyWith(
        color: primary,
        fontSize: 34,
      ),
      headlineLarge: AppTypography.display.copyWith(
        color: primary,
        fontSize: 30,
      ),
      headlineMedium: AppTypography.heading.copyWith(
        color: primary,
        fontSize: 22,
      ),
      titleLarge: AppTypography.heading.copyWith(color: primary),
      titleMedium: AppTypography.heading.copyWith(color: primary, fontSize: 16),
      bodyLarge: AppTypography.body.copyWith(color: primary, fontSize: 15),
      bodyMedium: AppTypography.body.copyWith(color: primary),
      bodySmall: AppTypography.metadata.copyWith(color: secondary),
      labelLarge: AppTypography.body.copyWith(
        color: primary,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: AppTypography.sectionLabel.copyWith(color: secondary),
      labelSmall: AppTypography.metadata.copyWith(color: secondary),
    );
  }

  static InputDecorationTheme _inputDecoration({
    required Color fill,
    required Color border,
    required Color focus,
  }) {
    OutlineInputBorder outline(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: outline(border),
      enabledBorder: outline(border),
      focusedBorder: outline(focus, 1.5),
      errorBorder: outline(AppColors.warningRed, 1.5),
      labelStyle: AppTypography.body,
      hintStyle: AppTypography.body,
    );
  }

  static ScrollbarThemeData _scrollbarTheme(Color accent) {
    return ScrollbarThemeData(
      thickness: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.hovered) ? 7 : 4,
      ),
      radius: const Radius.circular(2),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => accent.withValues(
          alpha: states.contains(WidgetState.hovered) ? 0.72 : 0.38,
        ),
      ),
      trackColor: const WidgetStatePropertyAll(Colors.transparent),
    );
  }

  static ButtonStyle _buttonStyle(Color accent, Color border) {
    return ButtonStyle(
      animationDuration: const Duration(milliseconds: 140),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: border),
        ),
      ),
      textStyle: const WidgetStatePropertyAll(AppTypography.body),
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
            ? selectedThumb.withValues(alpha: 0.7)
            : outline;
      }),
      trackOutlineWidth: const WidgetStatePropertyAll(1),
    );
  }

  static ThemeData _theme({
    required Brightness brightness,
    required Color accent,
  }) {
    final light = brightness == Brightness.light;
    final background = light
        ? AppColors.lightBackground
        : AppColors.darkBackground;
    final surface = light
        ? AppColors.lightBackgroundSecondary
        : AppColors.darkBackgroundSecondary;
    final elevated = light
        ? const Color(0xFFF7F3EA)
        : AppColors.darkBackgroundTertiary;
    final border = light ? const Color(0xFFBEC3C2) : const Color(0xFF465159);
    final primaryText = light ? AppColors.ink : const Color(0xFFF0F1ED);
    final secondaryText = light
        ? const Color(0xFF55636A)
        : const Color(0xFFB5BEBD);

    final buttonStyle = _buttonStyle(accent, border);
    return ThemeData(
      brightness: brightness,
      visualDensity: VisualDensity.compact,
      fontFamily: AppTypography.bodyFamily,
      scaffoldBackgroundColor: background,
      splashFactory: InkRipple.splashFactory,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: brightness,
        surface: surface,
        error: AppColors.warningRed,
      ),
      textTheme: _textTheme(primaryText, secondaryText),
      dividerColor: border,
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: _inputDecoration(
        fill: light ? const Color(0xFFE2DED5) : const Color(0xFF272E33),
        border: border,
        focus: accent,
      ),
      scrollbarTheme: _scrollbarTheme(accent),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: elevated,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: light ? 0.16 : 0.32),
              offset: const Offset(0, 5),
              blurRadius: 14,
            ),
          ],
        ),
        textStyle: AppTypography.metadata.copyWith(color: primaryText),
        waitDuration: const Duration(milliseconds: 420),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: elevated,
        elevation: 18,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: border),
        ),
        titleTextStyle: AppTypography.heading.copyWith(color: primaryText),
        contentTextStyle: AppTypography.body.copyWith(color: primaryText),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: elevated,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: light ? AppColors.ink : const Color(0xFFE8E3D8),
        contentTextStyle: AppTypography.body.copyWith(
          color: light ? const Color(0xFFF4F1E8) : AppColors.ink,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: buttonStyle),
      textButtonTheme: TextButtonThemeData(style: buttonStyle),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(38, 38),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: border),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: accent.withValues(alpha: 0.12),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        labelStyle: AppTypography.metadata.copyWith(color: primaryText),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(
          accent.withValues(alpha: light ? 0.06 : 0.1),
        ),
        dividerThickness: 1,
        headingTextStyle: AppTypography.sectionLabel.copyWith(
          color: secondaryText,
        ),
        dataTextStyle: AppTypography.body.copyWith(color: primaryText),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: border.withValues(alpha: 0.55),
      ),
      switchTheme: _switchTheme(
        selectedThumb: light
            ? const Color(0xFFFFFFFF)
            : const Color(0xFFE8E3D8),
        selectedTrack: accent,
        unselectedThumb: light
            ? const Color(0xFFFFFFFF)
            : const Color(0xFFBEC5C5),
        unselectedTrack: light
            ? const Color(0xFFD0CEC7)
            : const Color(0xFF343C42),
        outline: border,
      ),
    );
  }

  static ThemeData darkTheme(Color accent) =>
      _theme(brightness: Brightness.dark, accent: accent);

  static ThemeData lightTheme(Color accent) =>
      _theme(brightness: Brightness.light, accent: accent);
}
