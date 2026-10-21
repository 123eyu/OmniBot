import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ui/features/task/pages/usage_statistics/widgets/activity_dashboard_card.dart';
import 'package:ui/l10n/legacy_text_localizer.dart';
import 'package:ui/services/storage_service.dart';

void main() {
  const assistCoreChannel = MethodChannel(
    'cn.com.omnimind.bot/AssistCoreEvent',
  );

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
    LegacyTextLocalizer.setResolvedLocale(const Locale('zh'));
  });

  tearDown(() {
    LegacyTextLocalizer.clearResolvedLocale();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(assistCoreChannel, null);
  });

  testWidgets('shows conversation, per-model token, and cache statistics', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(assistCoreChannel, (call) async {
          switch (call.method) {
            case 'getConversationActivitySummary':
              return <String, Object?>{
                'activityMap': {
                  _dateKey(today): 1,
                  _dateKey(today.subtract(const Duration(days: 1))): 1,
                },
                'totalConversations': 2,
                'currentStreak': 2,
              };
            case 'getTokenUsageSummary':
              final arguments = call.arguments as Map;
              return <String, Object?>{
                'weeklyData': [
                  for (final start in arguments['weekStartsMs'] as List)
                    {
                      'weekStartMs': start,
                      'modelTokens':
                          start == (arguments['weekStartsMs'] as List).last
                          ? {'gpt-4o': 300, 'qwen3': 600}
                          : <String, int>{},
                      'cachedTokens':
                          start == (arguments['weekStartsMs'] as List).last
                          ? 400
                          : 0,
                    },
                ],
                'totalCached': 400,
                'modelTotals': {'gpt-4o': 300, 'qwen3': 600},
                'modelOrder': ['qwen3', 'gpt-4o'],
              };
            default:
              return null;
          }
        });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 375,
            child: ActivityDashboardCard(weeksToShow: 4),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('900'), findsOneWidget);
    expect(find.text('tokens'), findsOneWidget);
    expect(find.text('400'), findsOneWidget);
    expect(find.text('缓存'), findsOneWidget);
    final content = tester.widget<Padding>(
      find.byKey(const ValueKey('usage-statistics-content')),
    );
    expect(content.padding, const EdgeInsets.symmetric(horizontal: 20));
    expect(content.child, isA<FadeTransition>());

    await tester.tap(find.text('Token'));
    await tester.pumpAndSettle();

    expect(find.text('qwen3'), findsOneWidget);
    expect(find.text('gpt-4o'), findsOneWidget);
    expect(find.text('67%'), findsOneWidget);
    expect(find.text('33%'), findsOneWidget);
    expect(find.text('openai/gpt-4o'), findsNothing);
  });
}

String _dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
