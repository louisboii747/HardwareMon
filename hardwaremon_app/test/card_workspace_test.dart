import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gui/windows_ui/models/card_workspace.dart';
import 'package:flutter_gui/windows_ui/widgets/card_workspace.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('card state persists order visibility size and named layouts', () async {
    final preferences = CardWorkspacePreferences();
    await preferences.load();
    const defaults = ['cpu', 'gpu', 'memory'];

    await preferences.reorder('performance', defaults, 2, 0);
    await preferences.setVisible('performance', defaults, 'gpu', false);
    await preferences.setSize(
      'performance',
      defaults,
      'memory',
      WorkspaceCardSize.large,
    );
    await preferences.saveLayout('Diagnostics');

    final configured = preferences.resolve('performance', defaults);
    expect(configured.map((card) => card.id), ['memory', 'cpu', 'gpu']);
    expect(configured.last.visible, isFalse);
    expect(configured.first.size, WorkspaceCardSize.large);
    expect(preferences.savedLayouts.single.name, 'Diagnostics');

    await preferences.resetPage('performance');
    expect(
      preferences.resolve('performance', defaults).map((card) => card.id),
      defaults,
    );
    await preferences.applyLayout(preferences.savedLayouts.single.id);
    expect(preferences.resolve('performance', defaults).first.id, 'memory');
  });

  testWidgets('workspace can hide and restore a card at compact width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preferences = CardWorkspacePreferences();
    await preferences.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: CardWorkspace(
              pageId: 'test-page',
              pageLabel: 'Test page',
              preferences: preferences,
              standardHeight: 160,
              cards: const [
                WorkspaceCard(
                  id: 'cpu',
                  title: 'CPU',
                  child: Card(child: Center(child: Text('CPU CARD'))),
                ),
                WorkspaceCard(
                  id: 'gpu',
                  title: 'GPU',
                  child: Card(child: Center(child: Text('GPU CARD'))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Arrange cards'));
    await tester.pump();

    final draggables = find.byWidgetPredicate(
      (widget) => widget is Draggable<String>,
    );
    final gesture = await tester.startGesture(
      tester.getCenter(draggables.first),
    );
    await gesture.moveTo(tester.getCenter(draggables.last));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(
      preferences.resolve('test-page', const ['cpu', 'gpu']).first.id,
      'gpu',
    );

    await tester.tap(find.byTooltip('Remove card').first);
    await tester.pump();

    expect(
      preferences.resolve('test-page', const ['cpu', 'gpu']).first.visible,
      isFalse,
    );
    expect(find.text('1 hidden'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
