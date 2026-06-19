import 'package:flutter/foundation.dart';

import '../../models/app_settings.dart';
import '../../services/settings_service.dart';

class AppThemeController extends ChangeNotifier {
  AppThemeController._();

  static final AppThemeController instance = AppThemeController._();

  String _theme = const AppSettings().theme;

  String get theme => _theme;

  bool get isLight => _theme == 'Light';

  Future<void> load() async {
    final settings = await SettingsService().loadSettings();
    _theme = settings.theme;
    notifyListeners();
  }

  void setTheme(String theme) {
    if (_theme == theme) {
      return;
    }

    _theme = theme;
    notifyListeners();
  }
}
