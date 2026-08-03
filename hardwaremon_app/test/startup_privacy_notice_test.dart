import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_gui/windows_ui/services/privacy_notice_service.dart';
import 'package:flutter_gui/windows_ui/widgets/startup_privacy_notice.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'first launch shows responsive privacy screen and persists acceptance',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: ThemeData.dark(), home: const _NoticeHost()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Privacy & Data'), findsOneWidget);
      expect(find.text('Kept on this device'), findsOneWidget);
      expect(find.text('Features that use the network'), findsOneWidget);
      expect(find.text('Read full privacy policy'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 300));
      final acknowledgement = await PrivacyNoticeService().load();
      expect(
        acknowledgement.acceptedVersion,
        PrivacyNoticeService.currentVersion,
      );
      expect(await PrivacyNoticeService().shouldShow(), isFalse);
    },
  );

  test(
    'older policy version prompts again and corrupt values fail safely',
    () async {
      SharedPreferences.setMockInitialValues({
        'privacy.accepted_notice_version':
            PrivacyNoticeService.currentVersion - 1,
        'privacy.accepted_at_utc': 'not-a-date',
      });
      final service = PrivacyNoticeService();
      expect(await service.shouldShow(), isTrue);
      expect((await service.load()).acceptedAtUtc, isNull);
    },
  );
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
      if (mounted) StartupPrivacyNotice.showIfRequired(context);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.expand());
}
