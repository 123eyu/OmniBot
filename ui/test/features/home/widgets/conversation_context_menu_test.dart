import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/features/home/widgets/conversation_context_menu.dart';
import 'package:ui/theme/app_theme.dart';

void main() {
  testWidgets('bottom-row menu remains visible and outside tap dismisses it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 792);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var backgroundTaps = 0;
    await tester.pumpWidget(_host(onBackgroundTap: () => backgroundTaps++));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final preview = tester.getRect(
      find.byKey(const ValueKey('conversation-context-preview')),
    );
    final lastAction = tester.getRect(find.text('Delete'));
    expect(preview.left, greaterThanOrEqualTo(24));
    expect(preview.right, lessThanOrEqualTo(336));
    expect(lastAction.bottom, lessThan(780));
    await tester.tapAt(const Offset(350, 100));
    await tester.pumpAndSettle();
    expect(find.byType(ConversationContextMenu), findsNothing);
    expect(backgroundTaps, 0);
    await tester.tapAt(const Offset(350, 100));
    expect(backgroundTaps, 1);
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short viewport and large text keep every action reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? result;
    await tester.pumpWidget(
      _host(scale: 1.8, keyboard: 180, onResult: (value) => result = value),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('conversation-context-scroll')),
      const Offset(0, -480),
    );
    await tester.pumpAndSettle();
    final action = find.text('Delete');
    expect(tester.getRect(action).bottom, lessThanOrEqualTo(300));
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(result, 'Delete');
    expect(find.byType(ConversationContextMenu), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Widget _host({
  double scale = 1,
  double keyboard = 0,
  ValueChanged<String?>? onResult,
  VoidCallback? onBackgroundTap,
}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        viewInsets: EdgeInsets.only(bottom: keyboard),
      ),
      child: child!,
    ),
    home: Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onBackgroundTap,
        child: SizedBox.expand(
          child: Align(
            alignment: Alignment.topLeft,
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  final result = await showGeneralDialog<String>(
                    context: context,
                    barrierDismissible: true,
                    barrierLabel: 'Dismiss',
                    barrierColor: Colors.transparent,
                    pageBuilder: (context, _, _) => ConversationContextMenu(
                      anchor: const Rect.fromLTWH(24, 700, 312, 50),
                      title: 'A selected conversation with a long title',
                      actions: [
                        for (final label in [
                          'Pin',
                          'Rename',
                          'Copy',
                          'Archive',
                          'Delete',
                        ])
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(label),
                            child: Text(label),
                          ),
                      ],
                    ),
                  );
                  onResult?.call(result);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
