import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/features/home/widgets/conversation_context_menu.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/flclash/liquid_glass.dart';

void main() {
  for (final closeWithAction in [false, true]) {
    testWidgets(
      'repeat dismiss during reverse preserves the underlay (action=$closeWithAction)',
      (tester) async {
        var resultCount = 0;
        String? selected;
        var backgroundTaps = 0;
        await tester.pumpWidget(
          _host(
            pushableUnderlay: true,
            onBackgroundTap: () => backgroundTaps++,
            onResult: (value) {
              resultCount++;
              selected = value;
            },
          ),
        );
        await tester.pumpAndSettle();
        final navigator = Navigator.of(tester.element(find.text('Open')));
        expect(navigator.canPop(), isTrue);
        final underlay = tester.state(
          find.byKey(const ValueKey('context-menu-underlay-page')),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        if (closeWithAction) {
          await tester.tap(find.text('Delete'));
        } else {
          await tester.tapAt(const Offset(8, 250));
        }
        // No pump: the synchronous guard must cover two pointer sequences in
        // the same frame, before the reverse AbsorbPointer has rebuilt.
        await tester.tapAt(const Offset(8, 250));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(const Offset(8, 250));
        await tester.pumpAndSettle();
        expect(find.byType(ConversationContextMenu), findsNothing);
        expect(find.text('Open'), findsOneWidget);
        expect(
          tester.state(
            find.byKey(const ValueKey('context-menu-underlay-page')),
          ),
          same(underlay),
        );
        expect(navigator.canPop(), isTrue);
        expect(resultCount, 1);
        expect(selected, closeWithAction ? 'Delete' : null);
        expect(backgroundTaps, 0);
        expect(find.text('Lower route'), findsNothing);
        navigator.pop();
        await tester.pumpAndSettle();
        expect(find.text('Lower route'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('every exterior gap dismisses without reaching the home page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var backgroundTaps = 0;
    await tester.pumpWidget(_host(onBackgroundTap: () => backgroundTaps++));
    for (final point in <Offset Function(Rect preview, Rect menu)>[
      (preview, menu) => Offset(preview.left - 8, preview.center.dy),
      (preview, menu) => Offset(preview.right + 8, preview.center.dy),
      (preview, menu) => Offset(menu.right + 8, menu.center.dy),
      (preview, menu) => Offset(preview.center.dx, preview.top - 8),
      (preview, menu) => Offset(preview.center.dx, menu.bottom + 8),
      (preview, menu) => Offset(preview.left + 8, preview.bottom + 7),
    ]) {
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final preview = tester.getRect(
        find.byKey(const ValueKey('conversation-context-preview')),
      );
      final menu = tester.getRect(
        find.byKey(const ValueKey('conversation-context-actions')),
      );
      await tester.tapAt(point(preview, menu));
      await tester.pumpAndSettle();
      expect(find.byType(ConversationContextMenu), findsNothing);
      expect(backgroundTaps, 0);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'preview and menu padding stay open while action preserves result',
    (tester) async {
      String? result;
      await tester.pumpWidget(_host(onResult: (value) => result = value));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final preview = tester.getRect(
        find.byKey(const ValueKey('conversation-context-preview')),
      );
      final menu = tester.getRect(
        find.byKey(const ValueKey('conversation-context-actions')),
      );
      await tester.tapAt(preview.center);
      await tester.pumpAndSettle();
      expect(find.byType(ConversationContextMenu), findsOneWidget);
      await tester.tapAt(menu.topLeft + const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byType(ConversationContextMenu), findsOneWidget);
      expect(result, isNull);
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      expect(result, 'Rename');
    },
  );

  testWidgets(
    'preview lifts first, menu follows, and dismissal reverses both',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host());
      final preview = find.byKey(
        const ValueKey('conversation-context-preview'),
      );
      double opacity() => tester
          .widget<LiquidGlassFade>(
            find.byKey(const ValueKey('conversation-context-actions-opacity')),
          )
          .opacity
          .value;
      await tester.tap(find.text('Open'));
      await tester.pump();
      final initial = tester.getRect(preview);
      expect(initial.top, 700);
      expect(opacity(), 0);
      double previewOpacity() => tester
          .widget<LiquidGlassFade>(
            find.byKey(const ValueKey('conversation-context-preview-opacity')),
          )
          .opacity
          .value;
      expect(previewOpacity(), 0);
      await tester.pump(const Duration(milliseconds: 60));
      final early = tester.getRect(preview);
      expect(early.top, lessThan(initial.top));
      expect(opacity(), 0);
      expect(previewOpacity(), inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 100));
      final middle = tester.getRect(preview);
      expect(middle.top, lessThan(early.top));
      expect(opacity(), inExclusiveRange(0, 1));
      expect(previewOpacity(), 1);
      await tester.pumpAndSettle();
      final settled = tester.getRect(preview);
      expect(settled.top, lessThan(middle.top));
      expect(opacity(), 1);
      await tester.tapAt(const Offset(8, 250));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.byType(ConversationContextMenu), findsOneWidget);
      expect(opacity(), lessThan(1));
      await tester.pump(const Duration(milliseconds: 120));
      final reversing = tester.getRect(preview);
      expect(reversing.top, greaterThan(settled.top));
      expect(reversing.top, lessThan(initial.top));
      await tester.pumpAndSettle();
      expect(find.byType(ConversationContextMenu), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion presents the final layout on its first frame', (
    tester,
  ) async {
    await tester.pumpWidget(_host(disableAnimations: true));
    await tester.tap(find.text('Open'));
    await tester.pump();
    expect(
      tester
          .widget<LiquidGlassFade>(
            find.byKey(const ValueKey('conversation-context-actions-opacity')),
          )
          .opacity
          .value,
      1,
    );
    final preview = find.byKey(const ValueKey('conversation-context-preview'));
    final initial = tester.getRect(preview);
    await tester.pump(const Duration(milliseconds: 160));
    expect(tester.getRect(preview), initial);
    await tester.pumpAndSettle();
    expect(tester.getRect(preview), initial);
    await tester.tapAt(const Offset(8, 250));
    await tester.pump();
    await tester.pump();
    expect(find.byType(ConversationContextMenu), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('outside tap can reverse an unfinished lift without a jump', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host());
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final preview = find.byKey(const ValueKey('conversation-context-preview'));
    final before = tester.getRect(preview);
    await tester.tapAt(const Offset(8, 250));
    await tester.pump();
    expect(tester.getRect(preview), before);
    await tester.pump(const Duration(milliseconds: 30));
    expect(tester.getRect(preview).top, greaterThan(before.top));
    await tester.pumpAndSettle();
    expect(find.byType(ConversationContextMenu), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('visible menu padding does not dismiss during its reveal', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final menu = tester.getRect(
      find.byKey(const ValueKey('conversation-context-actions')),
    );
    await tester.tapAt(menu.topLeft + const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byType(ConversationContextMenu), findsOneWidget);
    await tester.tap(find.text('Pin'));
    await tester.pumpAndSettle();
    expect(find.byType(ConversationContextMenu), findsNothing);
    expect(tester.takeException(), isNull);
  });

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
      // Drag an actual action; the gap between surfaces is now dismissible.
      find.text('Pin'),
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
  bool disableAnimations = false,
  bool pushableUnderlay = false,
  ValueChanged<String?>? onResult,
  VoidCallback? onBackgroundTap,
}) {
  final page = Scaffold(
    key: const ValueKey('context-menu-underlay-page'),
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
                  transitionDuration: disableAnimations
                      ? Duration.zero
                      : const Duration(milliseconds: 320),
                  transitionBuilder: (_, animation, _, child) => AbsorbPointer(
                    absorbing: animation.status == AnimationStatus.reverse,
                    child: child,
                  ),
                  pageBuilder: (context, animation, _) =>
                      ConversationContextMenu(
                        anchor: const Rect.fromLTWH(24, 700, 312, 50),
                        title: 'A selected conversation with a long title',
                        animation: animation,
                        onDismiss: () => Navigator.of(context).pop(),
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
  );
  return MaterialApp(
    theme: AppTheme.lightTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        viewInsets: EdgeInsets.only(bottom: keyboard),
        disableAnimations: disableAnimations,
      ),
      child: child!,
    ),
    home: pushableUnderlay ? const Scaffold(body: Text('Lower route')) : page,
    initialRoute: pushableUnderlay ? '/conversation' : '/',
    routes: {'/conversation': (_) => page},
  );
}
