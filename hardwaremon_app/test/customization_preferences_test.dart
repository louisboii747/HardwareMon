import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_gui/windows_ui/models/chart_preferences.dart';
import 'package:flutter_gui/windows_ui/models/customization_preferences.dart';
import 'package:flutter_gui/windows_ui/models/dashboard_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'dashboard layout and studio controls persist across instances',
    () async {
      SharedPreferences.setMockInitialValues({});

      final dashboard = DashboardPreferences();
      await dashboard.load();
      await dashboard.reorderCard(0, 3);
      await dashboard.setCardVisible(DashboardMetricId.memory, false);
      await dashboard.setCardSize(DashboardCardSize.expanded);

      final studio = CustomizationPreferences();
      await studio.load();
      await studio.setSidebarMode(SidebarMode.expanded);
      await studio.setShowSidebarLabels(true);
      await studio.setSidebarIconSize(30);
      await studio.setMotionLevel(MotionLevel.cinematic);
      await studio.setAmbientGlowIntensity(1.2);

      final restoredDashboard = DashboardPreferences();
      final restoredStudio = CustomizationPreferences();
      await restoredDashboard.load();
      await restoredStudio.load();

      expect(restoredDashboard.cardOrder.first, DashboardMetricId.memory);
      expect(restoredDashboard.hiddenCards, contains(DashboardMetricId.memory));
      expect(restoredDashboard.cardSize, DashboardCardSize.expanded);
      expect(restoredStudio.sidebarMode, SidebarMode.expanded);
      expect(restoredStudio.showSidebarLabels, isTrue);
      expect(restoredStudio.sidebarIconSize, 30);
      expect(restoredStudio.motionLevel, MotionLevel.cinematic);
      expect(restoredStudio.ambientGlowIntensity, 1.2);
    },
  );

  test(
    'customization profiles serialize and restore the full studio',
    () async {
      SharedPreferences.setMockInitialValues({});

      final dashboard = DashboardPreferences();
      final charts = ChartPreferences();
      final studio = CustomizationPreferences();
      await dashboard.load();
      await charts.load();
      await studio.load();

      await charts.setThickness(3.5);
      await charts.setTimelineDensity(1.4);
      await studio.setWidgetEnabled(CustomWidgetId.weather, true);
      final profile = await studio.createProfile(
        name: 'Monitoring Wall',
        dashboard: dashboard,
        charts: charts,
      );

      final restored = CustomizationPreferences();
      await restored.load();

      expect(restored.profiles, hasLength(1));
      expect(restored.profiles.single.name, 'Monitoring Wall');
      expect(restored.activeProfileId, profile.id);
      expect(restored.profiles.single.data['charts']['thickness'], 3.5);
    },
  );
}
