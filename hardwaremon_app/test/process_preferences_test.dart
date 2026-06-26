import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_gui/windows_ui/models/process_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('process cockpit preferences persist locally', () async {
    SharedPreferences.setMockInitialValues({});

    final preferences = ProcessPreferences();
    await preferences.load();

    expect(preferences.hideSystemProcesses, isTrue);
    expect(preferences.autoRefresh, isTrue);
    expect(preferences.compactDensity, isFalse);
    expect(preferences.sort, ProcessSort.cpu);
    expect(preferences.quickFilter, ProcessQuickFilter.all);

    await preferences.setHideSystemProcesses(false);
    await preferences.setAutoRefresh(false);
    await preferences.setCompactDensity(true);
    await preferences.setSort(ProcessSort.activity);
    await preferences.setQuickFilter(ProcessQuickFilter.rising);
    await preferences.toggleWatched('Code.exe');

    final restored = ProcessPreferences();
    await restored.load();

    expect(restored.hideSystemProcesses, isFalse);
    expect(restored.autoRefresh, isFalse);
    expect(restored.compactDensity, isTrue);
    expect(restored.sort, ProcessSort.activity);
    expect(restored.quickFilter, ProcessQuickFilter.rising);
    expect(restored.isWatched('code.EXE'), isTrue);

    await restored.clearWatched();
    expect(restored.isWatched('Code.exe'), isFalse);
  });
}
