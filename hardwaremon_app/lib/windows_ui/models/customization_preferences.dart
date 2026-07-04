import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../core/theme/app_theme_controller.dart';
import '../core/theme/app_colors.dart';
import '../services/settings_service.dart';
import 'chart_preferences.dart';
import 'dashboard_preferences.dart';

enum SidebarMode { compact, expanded }

extension SidebarModeDetails on SidebarMode {
  String get label => switch (this) {
    SidebarMode.compact => 'Compact',
    SidebarMode.expanded => 'Expanded',
  };
}

enum MotionLevel { minimal, balanced, cinematic }

extension MotionLevelDetails on MotionLevel {
  String get label => switch (this) {
    MotionLevel.minimal => 'Minimal',
    MotionLevel.balanced => 'Balanced',
    MotionLevel.cinematic => 'Cinematic',
  };

  String get description => switch (this) {
    MotionLevel.minimal => 'Fast, quiet transitions with restrained effects',
    MotionLevel.balanced => 'Responsive motion with polished visual feedback',
    MotionLevel.cinematic => 'Layered entrances, ambient glow, and rich motion',
  };
}

enum CustomWidgetId {
  weather,
  networkSummary,
  hardwareHealth,
  activityFeed,
  benchmarks,
  updates,
}

extension CustomWidgetDetails on CustomWidgetId {
  String get label => switch (this) {
    CustomWidgetId.weather => 'Weather',
    CustomWidgetId.networkSummary => 'Network Summary',
    CustomWidgetId.hardwareHealth => 'Hardware Health',
    CustomWidgetId.activityFeed => 'Activity Feed',
    CustomWidgetId.benchmarks => 'Benchmarks',
    CustomWidgetId.updates => 'Updates',
  };
}

class CustomizationProfile {
  final String id;
  final String name;
  final DateTime updatedAt;
  final Map<String, dynamic> data;

  const CustomizationProfile({
    required this.id,
    required this.name,
    required this.updatedAt,
    required this.data,
  });

  CustomizationProfile copyWith({
    String? name,
    DateTime? updatedAt,
    Map<String, dynamic>? data,
  }) {
    return CustomizationProfile(
      id: id,
      name: name ?? this.name,
      updatedAt: updatedAt ?? this.updatedAt,
      data: data ?? this.data,
    );
  }

  Map<String, dynamic> toJson() => {
    'schema': 1,
    'id': id,
    'name': name,
    'updated_at': updatedAt.toIso8601String(),
    'data': data,
  };

  factory CustomizationProfile.fromJson(Map<String, dynamic> json) {
    return CustomizationProfile(
      id:
          json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name']?.toString() ?? 'Imported profile',
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      data: Map<String, dynamic>.from(json['data'] as Map? ?? const {}),
    );
  }
}

class CustomizationPreferences extends ChangeNotifier {
  static const _sidebarModeKey = 'customizationSidebarMode';
  static const _sidebarLabelsKey = 'customizationSidebarLabels';
  static const _sidebarIconSizeKey = 'customizationSidebarIconSize';
  static const _sidebarAnimationKey = 'customizationSidebarAnimation';
  static const _motionLevelKey = 'customizationMotionLevel';
  static const _transitionSpeedKey = 'customizationTransitionSpeed';
  static const _hoverEffectsKey = 'customizationHoverEffects';
  static const _ambientGlowKey = 'customizationAmbientGlow';
  static const _widgetOrderKey = 'customizationWidgetOrder';
  static const _enabledWidgetsKey = 'customizationEnabledWidgets';
  static const _weatherLocationKey = 'customizationWeatherLocation';
  static const _profilesKey = 'customizationProfiles';
  static const _activeProfileKey = 'customizationActiveProfile';

  final SettingsService _settingsService;

  CustomizationPreferences({SettingsService? settingsService})
    : _settingsService = settingsService ?? SettingsService();

  SidebarMode sidebarMode = SidebarMode.compact;
  bool showSidebarLabels = false;
  double sidebarIconSize = 24;
  double sidebarAnimationIntensity = 1;
  MotionLevel motionLevel = MotionLevel.balanced;
  double transitionSpeed = 1;
  bool hoverEffects = true;
  double ambientGlowIntensity = 0.75;
  List<CustomWidgetId> widgetOrder = List.of(CustomWidgetId.values);
  Set<CustomWidgetId> enabledWidgets = {
    CustomWidgetId.networkSummary,
    CustomWidgetId.hardwareHealth,
    CustomWidgetId.updates,
  };
  String weatherLocation = '';
  List<CustomizationProfile> profiles = [];
  String? activeProfileId;

  double get sidebarWidth {
    if (sidebarMode == SidebarMode.expanded || showSidebarLabels) return 188;
    return sidebarIconSize >= 29 ? 96 : 88;
  }

  Duration get transitionDuration {
    if (motionLevel == MotionLevel.minimal) {
      return Duration(milliseconds: (180 / transitionSpeed).round());
    }
    final base = motionLevel == MotionLevel.cinematic ? 560 : 420;
    return Duration(milliseconds: (base / transitionSpeed).round());
  }

  bool get animationsEnabled => motionLevel != MotionLevel.minimal;

  Future<void> load() async {
    sidebarMode = _enumValue(
      SidebarMode.values,
      await _settingsService.getString(
        _sidebarModeKey,
        SidebarMode.compact.name,
      ),
      SidebarMode.compact,
    );
    showSidebarLabels = await _settingsService.getBool(
      _sidebarLabelsKey,
      false,
    );
    sidebarIconSize = await _settingsService.getDouble(_sidebarIconSizeKey, 24);
    sidebarAnimationIntensity = await _settingsService.getDouble(
      _sidebarAnimationKey,
      1,
    );
    AppColors.setSidebarMotionIntensity(sidebarAnimationIntensity);
    motionLevel = _enumValue(
      MotionLevel.values,
      await _settingsService.getString(
        _motionLevelKey,
        MotionLevel.balanced.name,
      ),
      MotionLevel.balanced,
    );
    transitionSpeed = await _settingsService.getDouble(_transitionSpeedKey, 1);
    hoverEffects = await _settingsService.getBool(_hoverEffectsKey, true);
    ambientGlowIntensity = await _settingsService.getDouble(
      _ambientGlowKey,
      0.75,
    );
    widgetOrder = _widgetList(
      await _settingsService.getString(
        _widgetOrderKey,
        CustomWidgetId.values.map((item) => item.name).join(','),
      ),
      appendMissing: true,
    );
    enabledWidgets = _widgetList(
      await _settingsService.getString(
        _enabledWidgetsKey,
        enabledWidgets.map((item) => item.name).join(','),
      ),
    ).toSet();
    weatherLocation = await _settingsService.getString(_weatherLocationKey, '');
    activeProfileId = await _settingsService.getString(_activeProfileKey, '');
    if (activeProfileId?.isEmpty == true) activeProfileId = null;

    final storedProfiles = await _settingsService.getString(_profilesKey, '');
    if (storedProfiles.isNotEmpty) {
      try {
        final decoded = jsonDecode(storedProfiles) as List<dynamic>;
        profiles = decoded
            .whereType<Map>()
            .map(
              (item) => CustomizationProfile.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList();
      } catch (_) {
        profiles = [];
      }
    }
    notifyListeners();
  }

  Future<void> setSidebarMode(SidebarMode value) async {
    sidebarMode = value;
    notifyListeners();
    await _settingsService.setString(_sidebarModeKey, value.name);
  }

  Future<void> setShowSidebarLabels(bool value) async {
    showSidebarLabels = value;
    notifyListeners();
    await _settingsService.setBool(_sidebarLabelsKey, value);
  }

  Future<void> setSidebarIconSize(double value) async {
    sidebarIconSize = value.clamp(18, 34);
    notifyListeners();
    await _settingsService.setDouble(_sidebarIconSizeKey, sidebarIconSize);
  }

  Future<void> setSidebarAnimationIntensity(double value) async {
    sidebarAnimationIntensity = value.clamp(0, 1.5);
    AppColors.setSidebarMotionIntensity(sidebarAnimationIntensity);
    notifyListeners();
    await _settingsService.setDouble(
      _sidebarAnimationKey,
      sidebarAnimationIntensity,
    );
  }

  Future<void> setMotionLevel(MotionLevel value) async {
    motionLevel = value;
    notifyListeners();
    await _settingsService.setString(_motionLevelKey, value.name);
  }

  Future<void> setTransitionSpeed(double value) async {
    transitionSpeed = value.clamp(0.6, 1.8);
    notifyListeners();
    await _settingsService.setDouble(_transitionSpeedKey, transitionSpeed);
  }

  Future<void> setHoverEffects(bool value) async {
    hoverEffects = value;
    notifyListeners();
    await _settingsService.setBool(_hoverEffectsKey, value);
  }

  Future<void> setAmbientGlowIntensity(double value) async {
    ambientGlowIntensity = value.clamp(0, 1.5);
    notifyListeners();
    await _settingsService.setDouble(_ambientGlowKey, ambientGlowIntensity);
  }

  Future<void> reorderWidget(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final updated = List<CustomWidgetId>.of(widgetOrder);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex.clamp(0, updated.length), item);
    widgetOrder = updated;
    notifyListeners();
    await _persistWidgets();
  }

  Future<void> setWidgetEnabled(CustomWidgetId id, bool enabled) async {
    if (enabled) {
      enabledWidgets.add(id);
    } else {
      enabledWidgets.remove(id);
    }
    notifyListeners();
    await _persistWidgets();
  }

  Future<void> setWeatherLocation(String value) async {
    weatherLocation = value.trim();
    notifyListeners();
    await _settingsService.setString(_weatherLocationKey, weatherLocation);
  }

  Future<CustomizationProfile> createProfile({
    required String name,
    required DashboardPreferences dashboard,
    required ChartPreferences charts,
  }) async {
    final profile = CustomizationProfile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? 'Untitled profile' : name.trim(),
      updatedAt: DateTime.now(),
      data: captureSnapshot(dashboard: dashboard, charts: charts),
    );
    profiles = [...profiles, profile];
    activeProfileId = profile.id;
    notifyListeners();
    await _persistProfiles();
    return profile;
  }

  Future<void> updateProfile(
    String id, {
    required DashboardPreferences dashboard,
    required ChartPreferences charts,
  }) async {
    profiles = [
      for (final profile in profiles)
        if (profile.id == id)
          profile.copyWith(
            updatedAt: DateTime.now(),
            data: captureSnapshot(dashboard: dashboard, charts: charts),
          )
        else
          profile,
    ];
    activeProfileId = id;
    notifyListeners();
    await _persistProfiles();
  }

  Future<void> renameProfile(String id, String name) async {
    profiles = [
      for (final profile in profiles)
        profile.id == id
            ? profile.copyWith(name: name.trim(), updatedAt: DateTime.now())
            : profile,
    ];
    notifyListeners();
    await _persistProfiles();
  }

  Future<void> deleteProfile(String id) async {
    profiles = profiles.where((profile) => profile.id != id).toList();
    if (activeProfileId == id) activeProfileId = null;
    notifyListeners();
    await _persistProfiles();
  }

  Future<CustomizationProfile> importProfile(String source) async {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Profile JSON must contain an object.');
    }
    final imported =
        CustomizationProfile.fromJson(
          Map<String, dynamic>.from(decoded),
        ).copyWith(
          name:
              '${CustomizationProfile.fromJson(Map<String, dynamic>.from(decoded)).name} (Imported)',
          updatedAt: DateTime.now(),
        );
    final profile = CustomizationProfile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: imported.name,
      updatedAt: imported.updatedAt,
      data: imported.data,
    );
    profiles = [...profiles, profile];
    activeProfileId = profile.id;
    notifyListeners();
    await _persistProfiles();
    return profile;
  }

  Future<String> exportProfile(CustomizationProfile profile) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${documents.path}${Platform.pathSeparator}HardwareMon'
      '${Platform.pathSeparator}profiles',
    );
    await directory.create(recursive: true);
    final safeName = profile.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File(
      '${directory.path}${Platform.pathSeparator}$safeName.hardwaremon-profile.json',
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(profile.toJson()),
      flush: true,
    );
    return file.path;
  }

  Map<String, dynamic> captureSnapshot({
    required DashboardPreferences dashboard,
    required ChartPreferences charts,
  }) {
    return {
      'theme': AppThemeController.instance.theme,
      'accent': AppThemeController.instance.accent.toARGB32(),
      'dashboard': {
        'workspace': dashboard.workspace.name,
        'order': dashboard.cardOrder.map((item) => item.name).toList(),
        'hidden': dashboard.hiddenCards.map((item) => item.name).toList(),
        'size': dashboard.cardSize.name,
      },
      'charts': {
        'smooth_lines': charts.smoothLines,
        'area_fill': charts.areaFill,
        'grid_lines': charts.gridLines,
        'animations': charts.animations,
        'smoothness': charts.smoothness,
        'thickness': charts.thickness,
        'timeline_density': charts.timelineDensity,
        'animation_speed': charts.animationSpeed.name,
      },
      'studio': {
        'sidebar_mode': sidebarMode.name,
        'sidebar_labels': showSidebarLabels,
        'sidebar_icon_size': sidebarIconSize,
        'sidebar_animation': sidebarAnimationIntensity,
        'motion_level': motionLevel.name,
        'transition_speed': transitionSpeed,
        'hover_effects': hoverEffects,
        'ambient_glow': ambientGlowIntensity,
        'widget_order': widgetOrder.map((item) => item.name).toList(),
        'enabled_widgets': enabledWidgets.map((item) => item.name).toList(),
        'weather_location': weatherLocation,
      },
    };
  }

  Future<void> applyProfile(
    CustomizationProfile profile, {
    required DashboardPreferences dashboard,
    required ChartPreferences charts,
  }) async {
    final data = profile.data;
    await AppThemeController.instance.setThemeAndPersist(
      data['theme']?.toString() ?? 'Dark',
    );
    await AppThemeController.instance.setAccent(
      Color((data['accent'] as num?)?.toInt() ?? 0xFF0891B2),
    );

    final dashboardData = Map<String, dynamic>.from(
      data['dashboard'] as Map? ?? const {},
    );
    await dashboard.applySnapshot(
      order: _dashboardMetrics(dashboardData['order']),
      hidden: _dashboardMetrics(dashboardData['hidden']).toSet(),
      size: _enumValue(
        DashboardCardSize.values,
        dashboardData['size']?.toString() ?? '',
        DashboardCardSize.comfortable,
      ),
      selectedWorkspace: _enumValue(
        DashboardWorkspace.values,
        dashboardData['workspace']?.toString() ?? '',
        DashboardWorkspace.overview,
      ),
    );

    final chartData = Map<String, dynamic>.from(
      data['charts'] as Map? ?? const {},
    );
    await charts.setPreference(
      ChartPreference.areaFill,
      chartData['area_fill'] != false,
    );
    await charts.setPreference(
      ChartPreference.gridLines,
      chartData['grid_lines'] != false,
    );
    await charts.setPreference(
      ChartPreference.animations,
      chartData['animations'] != false,
    );
    await charts.setSmoothness(
      (chartData['smoothness'] as num?)?.toDouble() ?? 0.38,
    );
    await charts.setPreference(
      ChartPreference.smoothLines,
      chartData['smooth_lines'] != false,
    );
    await charts.setThickness(
      (chartData['thickness'] as num?)?.toDouble() ?? 2,
    );
    await charts.setTimelineDensity(
      (chartData['timeline_density'] as num?)?.toDouble() ?? 1,
    );
    await charts.setAnimationSpeed(
      _enumValue(
        GraphAnimationSpeed.values,
        chartData['animation_speed']?.toString() ?? '',
        GraphAnimationSpeed.balanced,
      ),
    );

    final studio = Map<String, dynamic>.from(
      data['studio'] as Map? ?? const {},
    );
    sidebarMode = _enumValue(
      SidebarMode.values,
      studio['sidebar_mode']?.toString() ?? '',
      SidebarMode.compact,
    );
    showSidebarLabels = studio['sidebar_labels'] == true;
    sidebarIconSize = (studio['sidebar_icon_size'] as num?)?.toDouble() ?? 24;
    sidebarAnimationIntensity =
        (studio['sidebar_animation'] as num?)?.toDouble() ?? 1;
    AppColors.setSidebarMotionIntensity(sidebarAnimationIntensity);
    motionLevel = _enumValue(
      MotionLevel.values,
      studio['motion_level']?.toString() ?? '',
      MotionLevel.balanced,
    );
    transitionSpeed = (studio['transition_speed'] as num?)?.toDouble() ?? 1;
    hoverEffects = studio['hover_effects'] != false;
    ambientGlowIntensity = (studio['ambient_glow'] as num?)?.toDouble() ?? 0.75;
    widgetOrder = _widgetList(studio['widget_order'], appendMissing: true);
    enabledWidgets = _widgetList(studio['enabled_widgets']).toSet();
    weatherLocation = studio['weather_location']?.toString().trim() ?? '';
    activeProfileId = profile.id;
    notifyListeners();
    await Future.wait([
      _persistStudio(),
      _persistWidgets(),
      _persistProfiles(),
    ]);
  }

  Future<void> resetStudioDefaults() async {
    sidebarMode = SidebarMode.compact;
    showSidebarLabels = false;
    sidebarIconSize = 24;
    sidebarAnimationIntensity = 1;
    AppColors.setSidebarMotionIntensity(sidebarAnimationIntensity);
    motionLevel = MotionLevel.balanced;
    transitionSpeed = 1;
    hoverEffects = true;
    ambientGlowIntensity = 0.75;
    widgetOrder = List.of(CustomWidgetId.values);
    enabledWidgets = {
      CustomWidgetId.networkSummary,
      CustomWidgetId.hardwareHealth,
      CustomWidgetId.updates,
    };
    weatherLocation = '';
    notifyListeners();
    await Future.wait([_persistStudio(), _persistWidgets()]);
  }

  Future<void> _persistStudio() {
    return Future.wait([
      _settingsService.setString(_sidebarModeKey, sidebarMode.name),
      _settingsService.setBool(_sidebarLabelsKey, showSidebarLabels),
      _settingsService.setDouble(_sidebarIconSizeKey, sidebarIconSize),
      _settingsService.setDouble(
        _sidebarAnimationKey,
        sidebarAnimationIntensity,
      ),
      _settingsService.setString(_motionLevelKey, motionLevel.name),
      _settingsService.setDouble(_transitionSpeedKey, transitionSpeed),
      _settingsService.setBool(_hoverEffectsKey, hoverEffects),
      _settingsService.setDouble(_ambientGlowKey, ambientGlowIntensity),
    ]);
  }

  Future<void> _persistWidgets() {
    return Future.wait([
      _settingsService.setString(
        _widgetOrderKey,
        widgetOrder.map((item) => item.name).join(','),
      ),
      _settingsService.setString(
        _enabledWidgetsKey,
        enabledWidgets.map((item) => item.name).join(','),
      ),
      _settingsService.setString(_weatherLocationKey, weatherLocation),
    ]);
  }

  Future<void> _persistProfiles() {
    return Future.wait([
      _settingsService.setString(
        _profilesKey,
        jsonEncode(profiles.map((profile) => profile.toJson()).toList()),
      ),
      _settingsService.setString(_activeProfileKey, activeProfileId ?? ''),
    ]);
  }

  T _enumValue<T extends Enum>(List<T> values, String name, T fallback) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  List<CustomWidgetId> _widgetList(
    dynamic source, {
    bool appendMissing = false,
  }) {
    final names = source is List
        ? source.map((item) => item.toString())
        : source.toString().split(',');
    final result = <CustomWidgetId>[];
    for (final name in names) {
      for (final candidate in CustomWidgetId.values) {
        if (candidate.name == name && !result.contains(candidate)) {
          result.add(candidate);
        }
      }
    }
    if (appendMissing) {
      result.addAll(
        CustomWidgetId.values.where((item) => !result.contains(item)),
      );
    }
    return result;
  }

  List<DashboardMetricId> _dashboardMetrics(dynamic source) {
    if (source is! List) return [];
    final result = <DashboardMetricId>[];
    for (final name in source.map((item) => item.toString())) {
      for (final candidate in DashboardMetricId.values) {
        if (candidate.name == name && !result.contains(candidate)) {
          result.add(candidate);
        }
      }
    }
    return result;
  }
}
