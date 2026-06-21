import 'package:flutter/material.dart';

import '../../models/app_settings.dart';
import '../../services/settings_service.dart';
import 'app_colors.dart';

class AppThemeController extends ChangeNotifier {
  AppThemeController._();

  static final AppThemeController instance = AppThemeController._();

  String _theme = const AppSettings().theme;
  Color _accent = AppColors.accent;

  String get theme => _theme;

  bool get isLight => _theme == 'Light';
  Color get accent => _accent;

  ThemeMode get themeMode => switch (_theme) {
    'Light' => ThemeMode.light,
    'System' => ThemeMode.system,
    _ => ThemeMode.dark,
  };

  Future<void> load() async {
    final service = SettingsService();
    final settings = await service.loadSettings();
    _theme = settings.theme;
    final accentValue = await service.getString(
      'customizationAccentColor',
      AppColors.accent.toARGB32().toString(),
    );
    _accent = Color(int.tryParse(accentValue) ?? AppColors.accent.toARGB32());
    AppColors.setAccent(_accent);
    notifyListeners();
  }

  void setTheme(String theme) {
    if (_theme == theme) {
      return;
    }

    _theme = theme;
    notifyListeners();
  }

  Future<void> setThemeAndPersist(String theme) async {
    setTheme(theme);
    final settingsService = SettingsService();
    final settings = await settingsService.loadSettings();
    await settingsService.saveSettings(settings.copyWith(theme: theme));
  }

  Future<void> setAccent(Color color) async {
    if (_accent == color) return;
    _accent = color;
    AppColors.setAccent(color);
    notifyListeners();
    await SettingsService().setString(
      'customizationAccentColor',
      color.toARGB32().toString(),
    );
  }
}
