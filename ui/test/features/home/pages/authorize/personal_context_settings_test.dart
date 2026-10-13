import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/features/home/pages/authorize_setting/authorize_setting_page.dart';
import 'package:ui/l10n/generated/app_localizations.dart';
import 'package:ui/services/special_permission.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'personal context is optional and only tapped source is requested',
    (tester) async {
      final requests = <MethodCall>[];
      var calendarStatus = 'denied';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        spePermission,
        (call) async {
          if (call.method == 'getPersonalContextCapabilities') {
            return [
              {'id': 'calendar_read', 'status': calendarStatus},
              {'id': 'calendar_write', 'status': 'denied'},
              {
                'id': 'location',
                'status': 'partial',
                'scope': ['approximate'],
              },
              {'id': 'background_location', 'status': 'denied'},
              {'id': 'sms', 'status': 'restricted'},
              {'id': 'environment', 'status': 'granted'},
            ];
          }
          if (call.method == 'requestPersonalContextAccess') {
            requests.add(call);
            return null;
          }
          if (call.method == 'getShizukuStatus') return <String, dynamic>{};
          return false;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AuthorizeSettingPage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests, isEmpty);
      await tester.scrollUntilVisible(find.text('读取日历'), 400);
      await tester.tap(find.text('读取日历'));
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
      expect(requests.single.arguments['capabilityId'], 'calendar_read');
      calendarStatus = 'granted';
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
      await tester.scrollUntilVisible(find.text('读取短信'), 400);
      expect(find.text('系统受限'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        spePermission,
        null,
      );
    },
  );
}
