import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_gui/windows_ui/models/monitoring_lens.dart';
import 'package:flutter_gui/windows_ui/models/session_journal.dart';
import 'package:flutter_gui/windows_ui/models/telemetry_insights.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const profile = SystemHealthProfile(
    overallScore: 84,
    stateLabel: 'Healthy',
    observation: 'The system is balancing the current workload.',
    bottleneck: 'No active bottleneck',
    signals: [],
  );

  test(
    'session journal captures, restores, and removes local snapshots',
    () async {
      SharedPreferences.setMockInitialValues({});
      final journal = SessionJournal();
      final captured = await journal.capture(
        profile: profile,
        lens: MonitoringLens.reliability,
        cpuUsage: 34,
        ramUsage: 48,
        gpuUsage: 12,
        cpuTemperature: 57,
        gpuTemperature: 44,
      );

      final restored = SessionJournal();
      await restored.load();

      expect(restored.entries, hasLength(1));
      expect(restored.entries.single.lens, MonitoringLens.reliability);
      expect(restored.entries.single.report, contains('CPU: 34%'));

      await restored.remove(captured.id);
      expect(restored.entries, isEmpty);
    },
  );

  test('session journal stays bounded to the newest entries', () async {
    SharedPreferences.setMockInitialValues({});
    final journal = SessionJournal();

    for (var index = 0; index < SessionJournal.maxEntries + 3; index++) {
      await journal.capture(
        profile: profile,
        lens: MonitoringLens.balanced,
        cpuUsage: index,
        ramUsage: 40,
        gpuUsage: 10,
        cpuTemperature: 50,
        gpuTemperature: 45,
      );
    }

    expect(journal.entries, hasLength(SessionJournal.maxEntries));
    expect(journal.entries.first.cpuUsage, SessionJournal.maxEntries + 2);
  });
}
