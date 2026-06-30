import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gui/windows_ui/widgets/startup_privacy_notice.dart';

void main() {
  testWidgets('startup privacy notice is compact and opens details', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: ThemeData.dark(), home: const _NoticeHost()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('monitoring, diagnostics'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);

    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    expect(find.text('Privacy at a glance'), findsOneWidget);
    expect(find.text('Processed on this device'), findsOneWidget);
    expect(find.text('Stored locally'), findsOneWidget);
    expect(find.text('Internet and future features'), findsOneWidget);
    expect(
      find.textContaining('Benchmark results are not currently uploaded'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _NoticeHost extends StatefulWidget {
  const _NoticeHost();

  @override
  State<_NoticeHost> createState() => _NoticeHostState();
}

class _NoticeHostState extends State<_NoticeHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) StartupPrivacyNotice.show(context);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.expand());
}
