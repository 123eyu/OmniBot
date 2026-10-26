import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/widgets/glass_popup.dart';

const _panel = ValueKey('panel');

Widget _app({
  required Rect anchor,
  bool preferBelow = true,
  bool overlapAnchor = true,
  double keyboard = 0,
  bool reduceMotion = false,
  TextDirection direction = TextDirection.ltr,
  GlobalKey<GlassPopupOverlayContentState>? popupKey,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(400, 800),
      padding: const EdgeInsets.only(top: 24, bottom: 20),
      viewInsets: EdgeInsets.only(bottom: keyboard),
      disableAnimations: reduceMotion,
    ),
    child: Directionality(
      textDirection: direction,
      child: Stack(
        children: [
          GlassPopupOverlayContent(
            key: popupKey,
            anchor: anchor,
            preferBelow: preferBelow,
            overlapAnchor: overlapAnchor,
            child: const SizedBox(key: _panel, width: 220, height: 240),
          ),
        ],
      ),
    ),
  ),
);

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('covers corner triggers within safe bounds in $direction', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final anchor in [
        const Rect.fromLTWH(16, 40, 44, 44),
        const Rect.fromLTWH(340, 40, 44, 44),
        const Rect.fromLTWH(16, 700, 44, 44),
        const Rect.fromLTWH(340, 700, 44, 44),
      ]) {
        await tester.pumpWidget(_app(anchor: anchor, direction: direction));
        await tester.pumpAndSettle();
        final panel = tester.getRect(find.byKey(_panel));
        expect(panel.contains(anchor.topLeft), isTrue);
        expect(
          panel.contains(anchor.bottomRight - const Offset(0.1, 0.1)),
          isTrue,
        );
        expect(panel.left, greaterThanOrEqualTo(8));
        expect(panel.right, lessThanOrEqualTo(392));
        expect(panel.top, greaterThanOrEqualTo(32));
        expect(panel.bottom, lessThanOrEqualTo(772));
      }
    });
  }

  testWidgets(
    'keyboard keeps the visible trigger covered and panel reachable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const anchor = Rect.fromLTWH(20, 400, 100, 44);
      await tester.pumpWidget(
        _app(anchor: anchor, preferBelow: false, keyboard: 300),
      );
      await tester.pumpAndSettle();
      final panel = tester.getRect(find.byKey(_panel));
      expect(panel.contains(anchor.center), isTrue);
      expect(panel.bottom, lessThanOrEqualTo(472));
    },
  );

  testWidgets('adjacent cards retain the gap above their trigger', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const anchor = Rect.fromLTWH(20, 400, 44, 44);
    await tester.pumpWidget(
      _app(anchor: anchor, preferBelow: false, overlapAnchor: false),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(_panel)).bottom, anchor.top - 6);
  });

  testWidgets(
    'rounded reveal grows from trigger and reverses without relayout',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final key = GlobalKey<GlassPopupOverlayContentState>();
      await tester.pumpWidget(
        _app(anchor: const Rect.fromLTWH(20, 40, 44, 44), popupKey: key),
      );
      await tester.pump();
      final rect = tester.getRect(find.byKey(_panel));
      RRect clip() => tester
          .widget<ClipRRect>(find.byType(ClipRRect))
          .clipper!
          .getClip(rect.size);
      expect(clip().outerRect, const Rect.fromLTWH(0, 0, 44, 44));
      await tester.pump(const Duration(milliseconds: 60));
      expect(clip().width, greaterThan(44));
      expect(clip().width, lessThan(rect.width));
      // The covered corner stays aligned while content is being revealed;
      // opening the shadow gutter early used to pull these edges outward.
      expect(clip().left, 0);
      expect(clip().top, 0);
      expect(clip().tlRadiusX, greaterThan(0));
      expect(tester.getRect(find.byKey(_panel)), rect);
      await tester.pumpAndSettle();
      expect(clip().outerRect, (Offset.zero & rect.size).inflate(64));
      final closed = key.currentState!.playReverse();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(clip().width, lessThan(rect.width + 128));
      expect(tester.getRect(find.byKey(_panel)), rect);
      await tester.pumpAndSettle();
      await closed;
    },
  );

  testWidgets('dismissal during reveal continues without a geometry jump', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey<GlassPopupOverlayContentState>();
    await tester.pumpWidget(
      _app(anchor: const Rect.fromLTWH(20, 700, 40, 40), popupKey: key),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final panel = tester.getRect(find.byKey(_panel));
    RRect clip() => tester
        .widget<ClipRRect>(find.byType(ClipRRect))
        .clipper!
        .getClip(panel.size);
    final before = clip();
    final closed = key.currentState!.playReverse();
    await tester.pump();
    expect(clip(), before);
    await tester.pump(const Duration(milliseconds: 16));
    expect(clip().width, lessThan(before.width));
    expect(clip().left, 0);
    expect(clip().bottom, panel.height);
    expect(tester.getRect(find.byKey(_panel)), panel);
    await tester.pumpAndSettle();
    await closed;
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion shows the complete panel immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(anchor: const Rect.fromLTWH(20, 40, 44, 44), reduceMotion: true),
    );
    expect(find.byKey(_panel), findsOneWidget);
    expect(find.byType(ClipRRect), findsNothing);
  });
}
