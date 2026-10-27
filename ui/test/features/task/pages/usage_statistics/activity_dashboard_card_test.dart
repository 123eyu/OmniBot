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

  testWidgets(
    'shows user message counts, per-model token, and cache statistics',
    (tester) async {
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
      expect(content.padding, const EdgeInsets.symmetric(horizontal: 22));
      expect(content.child, isA<FadeTransition>());

      await tester.tap(find.text('Token'));
      await tester.pumpAndSettle();

      expect(find.text('qwen3'), findsOneWidget);
      expect(find.text('gpt-4o'), findsOneWidget);
      expect(find.text('67%'), findsOneWidget);
      expect(find.text('33%'), findsOneWidget);
      expect(find.text('openai/gpt-4o'), findsNothing);
    },
  );

  testWidgets(
    'token read failure shows retry and keeps conversation statistics',
    (tester) async {
      var tokenReads = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(assistCoreChannel, (call) async {
            if (call.method == 'getConversationActivitySummary') {
              return _conversationSummary();
            }
            if (call.method == 'getTokenUsageSummary') {
              if (++tokenReads == 1) {
                throw PlatformException(code: 'READ_FAILED');
              }
              return _tokenSummary(call, 725);
            }
            return null;
          });

      await tester.pumpWidget(_dashboard());
      await tester.pumpAndSettle();
      expect(find.text('13'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(find.text('0'), findsNothing);
      expect(find.text('暂无 Token 消耗数据'), findsNothing);

      await tester.tap(find.text('Token'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Token 统计加载失败，点击重试'));
      await tester.pumpAndSettle();

      expect(tokenReads, 2);
      expect(find.text('Token 统计加载失败，点击重试'), findsNothing);
      expect(find.text('725'), findsOneWidget);
      expect(find.text('model'), findsOneWidget);
      expect(find.text('13'), findsOneWidget);
    },
  );

  testWidgets(
    'conversation read failure retries without hiding token statistics',
    (tester) async {
      var conversationReads = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(assistCoreChannel, (call) async {
            if (call.method == 'getConversationActivitySummary') {
              if (++conversationReads == 1) {
                throw PlatformException(code: 'READ_FAILED');
              }
              return _conversationSummary();
            }
            if (call.method == 'getTokenUsageSummary') {
              return _tokenSummary(call, 725);
            }
            return null;
          });

      await tester.pumpWidget(_dashboard());
      await tester.pumpAndSettle();
      expect(find.text('725'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(2));
      expect(find.text('0'), findsNothing);

      await tester.tap(find.text('对话统计加载失败，点击重试'));
      await tester.pumpAndSettle();

      expect(conversationReads, 2);
      expect(find.text('对话统计加载失败，点击重试'), findsNothing);
      expect(find.text('13'), findsOneWidget);
      expect(find.text('725'), findsOneWidget);
    },
  );

  testWidgets('returning to the foreground refreshes both statistics', (
    tester,
  ) async {
    var conversationReads = 0;
    var tokenReads = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(assistCoreChannel, (call) async {
          if (call.method == 'getConversationActivitySummary') {
            conversationReads++;
            return _conversationSummary(
              count: conversationReads == 1 ? 13 : 14,
            );
          }
          if (call.method == 'getTokenUsageSummary') {
            tokenReads++;
            return _tokenSummary(call, tokenReads == 1 ? 725 : 840);
          }
          return null;
        });

    await tester.pumpWidget(_dashboard());
    await tester.pumpAndSettle();
    expect(find.text('13'), findsOneWidget);
    expect(find.text('725'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(conversationReads, 2);
    expect(tokenReads, 2);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('840'), findsOneWidget);
    expect(find.text('725'), findsNothing);
  });
}

Widget _dashboard() => const MaterialApp(
  home: Scaffold(
    body: SizedBox(width: 375, child: ActivityDashboardCard(weeksToShow: 4)),
  ),
);

Map<String, Object?> _conversationSummary({int count = 13}) => {
  'activityMap': {_dateKey(DateTime.now()): count},
  'totalConversations': count,
  'currentStreak': 1,
};

Map<String, Object?> _tokenSummary(MethodCall call, int tokens) {
  final starts = (call.arguments as Map)['weekStartsMs'] as List;
  return {
    'weeklyData': [
      for (final start in starts)
        {
          'weekStartMs': start,
          'modelTokens': start == starts.last
              ? {'model': tokens}
              : <String, int>{},
          'cachedTokens': 0,
        },
    ],
    'totalCached': 0,
    'modelTotals': {'model': tokens},
    'modelOrder': ['model'],
  };
}

String _dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
