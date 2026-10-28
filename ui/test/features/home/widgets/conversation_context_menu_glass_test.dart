import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/features/home/widgets/conversation_context_menu.dart';
import 'package:ui/widgets/flclash/liquid_glass.dart';
import 'package:ui/widgets/omni_glass.dart';

class _Harness {
  final navigator = GlobalKey<NavigatorState>();
  int backgroundTaps = 0;
  int previewTaps = 0;
  int actionTaps = 0;
  int dismissals = 0;
  String? appliedAction;
  late RawDialogRoute<String> route;
  late BuildContext menuContext;
  Future<void>? completion;

  Widget app({
    bool glass = true,
    LiquidGlassQuality quality = LiquidGlassQuality.standard,
    bool dark = false,
    EdgeInsets padding = EdgeInsets.zero,
    EdgeInsets viewInsets = EdgeInsets.zero,
    bool reducedMotion = false,
  }) => MaterialApp(
    navigatorKey: navigator,
    theme: dark ? ThemeData.dark() : ThemeData.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: padding,
        viewInsets: viewInsets,
        disableAnimations: reducedMotion,
      ),
      child: LiquidGlassScope(
        enabled: glass,
        quality: quality,
        child: LiquidGlassHost(enabled: glass, child: child!),
      ),
    ),
    home: Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => backgroundTaps++,
        child: const SizedBox.expand(),
      ),
    ),
  );

  void open({
    bool customPreview = true,
    int actionCount = 3,
    Rect anchor = const Rect.fromLTWH(24, 100, 330, 80),
    bool reducedMotion = false,
  }) {
    route = RawDialogRoute<String>(
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.transparent,
      transitionDuration: reducedMotion
          ? Duration.zero
          : const Duration(milliseconds: 320),
      pageBuilder: (context, animation, _) {
        menuContext = context;
        return ConversationContextMenu(
          anchor: anchor,
          title: 'Original conversation',
          animation: animation,
          onDismiss: () {
            dismissals++;
            Navigator.of(context).pop();
          },
          preview: customPreview
              ? OmniGlassPanel(
                  padding: const EdgeInsets.all(14),
                  child: InkWell(
                    onTap: () => previewTaps++,
                    child: const Row(
                      children: [
                        Icon(Icons.smart_toy_outlined),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Agent conversation'),
                              Text('Latest message summary'),
                              Text('Yesterday'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
          actions: List.generate(
            actionCount,
            (index) => TextButton(
              key: ValueKey('action-$index'),
              onPressed: () {
                if (ModalRoute.of(context)?.isCurrent != true) return;
                actionTaps++;
                Navigator.of(context).pop('action-$index');
              },
              child: Text('Action $index'),
            ),
          ),
        );
      },
      // Match the actual caller: ModalRoute ignores page hit testing while
      // reversing, so this outer owner must keep those taps off the page below.
      transitionBuilder: (_, animation, _, child) => AbsorbPointer(
        absorbing: animation.status == AnimationStatus.reverse,
        child: child,
      ),
    );
    completion = () async {
      final selected = await navigator.currentState!.push(route);
      await route.completed;
      appliedAction = selected;
    }();
  }

  void dismiss() => Navigator.of(menuContext).pop();
}

Finder get _preview =>
    find.byKey(const ValueKey('conversation-context-preview'));
Finder get _actions =>
    find.byKey(const ValueKey('conversation-context-actions'));

void main() {
  for (final quality in LiquidGlassQuality.values) {
    testWidgets(
      'glass keeps the complete rounded action pane while moving: $quality',
      (tester) async {
        final harness = _Harness();
        await tester.pumpWidget(harness.app(quality: quality));
        harness.open();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 128));

        void expectCompletePane() {
          final clips = tester.widgetList<ClipRect>(
            find.ancestor(of: _actions, matching: find.byType(ClipRect)),
          );
          expect(
            clips.where((clip) => clip.clipper != null),
            isEmpty,
            reason:
                'The reveal must never cut a flat edge through the glass pane',
          );
          final scale = tester
              .widget<Transform>(
                find.byKey(
                  const ValueKey('conversation-context-actions-scale'),
                ),
              )
              .transform
              .entry(0, 0);
          expect(scale, inExclusiveRange(0.96, 1));
          expect(
            tester.getRect(_actions).height,
            closeTo(tester.getSize(_actions).height * scale, 0.001),
            reason: 'The whole pane scales, retaining its full menu height',
          );
          final glass = tester.widget<LiquidGlass>(
            find.descendant(of: _actions, matching: find.byType(LiquidGlass)),
          );
          expect(glass.borderRadius, BorderRadius.circular(20));
          expect(
            tester
                .widget<SingleChildScrollView>(
                  find.byKey(const ValueKey('conversation-context-scroll')),
                )
                .clipBehavior,
            Clip.hardEdge,
            reason:
                'The enclosing viewport must still enforce screen safe areas',
          );
          expect(LiquidGlassHost.debugHeldCaptures, 2);
        }

        expectCompletePane();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('action-0')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expectCompletePane();
        expect(harness.appliedAction, isNull);
        await tester.pumpAndSettle();
        await harness.completion;
        expect(harness.appliedAction, 'action-0');
        expect(LiquidGlassHost.debugHeldCaptures, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final dark in [false, true]) {
    for (final quality in <LiquidGlassQuality?>[
      null,
      ...LiquidGlassQuality.values,
    ]) {
      testWidgets(
        'long-press surfaces use one background each: $quality dark=$dark',
        (tester) async {
          final harness = _Harness();
          await tester.pumpWidget(
            harness.app(
              glass: quality != null,
              quality: quality ?? LiquidGlassQuality.standard,
              dark: dark,
            ),
          );
          harness.open();
          await tester.pumpAndSettle();
          expect(find.text('Agent conversation'), findsOneWidget);
          expect(find.text('Latest message summary'), findsOneWidget);
          expect(find.text('Yesterday'), findsOneWidget);
          expect(find.text('Original conversation'), findsNothing);
          expect(
            find.byType(LiquidGlass),
            quality == null ? findsNothing : findsNWidgets(2),
            reason: 'The nested preview panel inherits its one surface owner',
          );
          expect(LiquidGlassHost.debugHeldCaptures, quality == null ? 0 : 2);
          expect(
            find.descendant(of: _preview, matching: find.byType(DecoratedBox)),
            quality == null ? findsOneWidget : findsNothing,
            reason: 'A translucent preview cannot also paint a solid card',
          );
          if (quality != null) {
            expect(LiquidGlassHost.debugLastCapture!.panes, hasLength(2));
          }
          await tester.tapAt(tester.getCenter(_preview));
          await tester.pump();
          expect(harness.previewTaps, 0);
          expect(harness.dismissals, 0);
          expect(find.byType(ConversationContextMenu), findsOneWidget);

          await tester.tap(find.byKey(const ValueKey('action-0')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 160));
          expect(harness.actionTaps, 1);
          expect(harness.appliedAction, isNull);
          expect(find.byType(ConversationContextMenu), findsOneWidget);
          final fade = tester.widget<LiquidGlassFade>(
            find.byKey(const ValueKey('conversation-context-actions-opacity')),
          );
          expect(fade.opacity.value, allOf(greaterThan(0), lessThan(1)));
          await tester.tapAt(const Offset(5, 5));
          await tester.tap(
            find.byKey(const ValueKey('action-1')),
            warnIfMissed: false,
          );
          await tester.pumpAndSettle();
          await harness.completion;
          expect(harness.appliedAction, 'action-0');
          expect(harness.actionTaps, 1);
          expect(harness.backgroundTaps, 0);
          expect(harness.dismissals, 0);
          expect(LiquidGlassHost.debugHeldCaptures, 0);
          expect(find.byType(ConversationContextMenu), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'default preview remains compatible and empty menu space dismisses',
    (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.app());
      harness.open(customPreview: false);
      await tester.pumpAndSettle();
      expect(find.text('Original conversation'), findsOneWidget);
      expect(tester.getSize(_preview).height, greaterThanOrEqualTo(54));
      final menu = tester.getRect(_actions);
      final preview = tester.getRect(_preview);
      await tester.tapAt(Offset(preview.right - 8, menu.center.dy));
      await tester.pumpAndSettle();
      await harness.completion;
      expect(harness.dismissals, 1);
      expect(harness.backgroundTaps, 0);
      expect(harness.appliedAction, isNull);
      expect(LiquidGlassHost.debugHeldCaptures, 0);
    },
  );

  testWidgets('early close and immediate reopen release all preview captures', (
    tester,
  ) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.app());
    for (final milliseconds in [16, 90, 230]) {
      harness.open();
      await tester.pump();
      await tester.pump(Duration(milliseconds: milliseconds));
      harness.dismiss();
      await tester.pumpAndSettle();
      await harness.completion;
      expect(LiquidGlassHost.debugHeldCaptures, 0);
      expect(find.byType(ConversationContextMenu), findsNothing);
    }
    harness.open();
    await tester.pumpAndSettle();
    expect(LiquidGlassHost.debugHeldCaptures, 2);
    harness.dismiss();
    await tester.pumpAndSettle();
    expect(LiquidGlassHost.debugHeldCaptures, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard and safe areas bound the scrollable action list', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final harness = _Harness();
    await tester.pumpWidget(
      harness.app(
        padding: const EdgeInsets.only(top: 30, bottom: 20),
        viewInsets: const EdgeInsets.only(bottom: 260),
      ),
    );
    harness.open(
      actionCount: 10,
      anchor: const Rect.fromLTWH(12, 500, 366, 90),
    );
    await tester.pumpAndSettle();
    final scroll = find.byKey(const ValueKey('conversation-context-scroll'));
    final bounds = tester.getRect(scroll);
    expect(bounds.top, greaterThanOrEqualTo(42));
    expect(bounds.bottom, lessThanOrEqualTo(368));
    expect(bounds.left, greaterThanOrEqualTo(24));
    expect(bounds.right, lessThanOrEqualTo(366));
    await tester.drag(scroll, const Offset(0, -450));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('action-9')));
    await tester.pumpAndSettle();
    await harness.completion;
    expect(harness.appliedAction, 'action-9');
    expect(LiquidGlassHost.debugHeldCaptures, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion still releases surfaces when route closes', (
    tester,
  ) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.app(reducedMotion: true));
    harness.open(reducedMotion: true);
    await tester.pumpAndSettle();
    expect(LiquidGlassHost.debugHeldCaptures, 2);
    await tester.tap(find.byKey(const ValueKey('action-0')));
    await tester.pumpAndSettle();
    await harness.completion;
    expect(harness.appliedAction, 'action-0');
    expect(LiquidGlassHost.debugHeldCaptures, 0);
    expect(tester.takeException(), isNull);
  });
}
