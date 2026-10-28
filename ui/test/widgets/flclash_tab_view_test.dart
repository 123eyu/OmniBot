import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/widgets/flclash/tab_view.dart';

void main() {
  testWidgets('cold destination is laid out before its slide clock starts', (
    tester,
  ) async {
    final created = <int>[];
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await tester.pumpWidget(_harness(selected, created, {}));
    selected.value = 3;
    await tester.pump();
    final prepared = find.byKey(const ValueKey('page-3'), skipOffstage: false);
    expect(created, [0, 3]);
    expect(tester.getRect(_page(0)).left, 0);
    expect(tester.getSize(prepared), tester.getSize(_page(0)));
    expect(tester.getRect(prepared).left, tester.getSize(_page(0)).width);
    // Reversing before the first movement cancels admission and does not visit
    // either intervening page while the prepared owner remains cached.
    selected.value = 0;
    await tester.pumpAndSettle();
    expect(created, [0, 3]);
    expect(tester.getRect(_page(0)).left, 0);
    expect(tester.takeException(), isNull);
  });

  for (final destination in [1, 3]) {
    testWidgets(
      '${destination == 1 ? 'adjacent' : 'cross-tab'} selection slides both pages together',
      (tester) async {
        final created = <int>[];
        final active = <int, bool>{};
        final selected = ValueNotifier(0);
        addTearDown(selected.dispose);
        await tester.pumpWidget(_harness(selected, created, active));
        await tester.enterText(_field(0), 'keep this query');
        final originalState = tester.state(_field(0));
        expect(created, [0]);
        final width = tester.getSize(_page(0)).width;

        selected.value = destination;
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 90));
        expect(created.toSet(), {0, destination});
        expect(active[0], isFalse);
        expect(active[destination], isTrue);
        final leaving = tester.getRect(_page(0));
        final arriving = tester.getRect(_page(destination));
        expect(leaving.left, lessThan(0));
        expect(arriving.left, greaterThan(0));
        expect(leaving.right, closeTo(arriving.left, .01));
        expect(
          leaving.left,
          closeTo(-width * Curves.easeOut.transform(90 / 300), .01),
        );
        await tester.pumpAndSettle();
        expect(find.text('Page $destination').hitTestable(), findsOneWidget);

        selected.value = 0;
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 90));
        expect(tester.getRect(_page(destination)).left, greaterThan(0));
        expect(tester.getRect(_page(0)).left, lessThan(0));
        expect(
          tester.getRect(_page(0)).right,
          closeTo(tester.getRect(_page(destination)).left, .01),
        );
        await tester.pumpAndSettle();
        expect(created, [0, destination]);
        expect(tester.state(_field(0)), same(originalState));
        expect(find.text('keep this query'), findsOneWidget);
        expect(active[destination], isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('RTL retains the PageView slide direction', (tester) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await tester.pumpWidget(_harness(selected, [], {}, rtl: true));
    selected.value = 3;
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(tester.getRect(_page(0)).left, greaterThan(0));
    expect(tester.getRect(_page(3)).left, lessThan(0));
    expect(
      tester.getRect(_page(3)).right,
      closeTo(tester.getRect(_page(0)).left, .01),
    );
    await tester.pumpAndSettle();
    expect(find.text('Page 3').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reversing a warped pair keeps both fractional page positions', (
    tester,
  ) async {
    final created = <int>[];
    final active = <int, bool>{};
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await tester.pumpWidget(_harness(selected, created, active));
    selected.value = 3;
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 75));
    final beforeReverse = [tester.getRect(_page(0)), tester.getRect(_page(3))];
    selected.value = 0;
    await tester.pump();
    await tester.pump();
    expect(tester.getRect(_page(0)), beforeReverse[0]);
    expect(tester.getRect(_page(3)), beforeReverse[1]);
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.getRect(_page(0)).left, greaterThan(beforeReverse[0].left));
    final beforeForward = [tester.getRect(_page(0)), tester.getRect(_page(3))];
    selected.value = 3;
    await tester.pump();
    await tester.pump();
    expect(tester.getRect(_page(0)), beforeForward[0]);
    expect(tester.getRect(_page(3)), beforeForward[1]);
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.getRect(_page(0)).left, lessThan(beforeForward[0].left));
    await tester.pumpAndSettle();
    expect(created, [0, 3]);
    expect(find.text('Page 3').hitTestable(), findsOneWidget);
    expect(_activePages(active), [3]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'only the latest queued third tab starts after the visible pair',
    (tester) async {
      final created = <int>[];
      final active = <int, bool>{};
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      await tester.pumpWidget(_harness(selected, created, active));
      selected.value = 3;
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      for (final index in [1, 2]) {
        final before = [tester.getRect(_page(0)), tester.getRect(_page(3))];
        selected.value = index;
        await tester.pump();
        await tester.pump();
        expect(tester.getRect(_page(0)), before[0]);
        expect(tester.getRect(_page(3)), before[1]);
        expect(created, [0, 3]);
        expect(_activePages(active), isEmpty);
      }
      await tester.pumpAndSettle();
      expect(created, [0, 3, 2]);
      expect(find.text('Page 2').hitTestable(), findsOneWidget);
      expect(_activePages(active), [2]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('returning to a visible page cancels all queued destinations', (
    tester,
  ) async {
    final created = <int>[];
    final active = <int, bool>{};
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await tester.pumpWidget(_harness(selected, created, active));
    for (final index in [3, 1, 2, 0, 3, 1, 0]) {
      selected.value = index;
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pumpAndSettle();
    expect(created, [0, 3]);
    expect(find.text('Page 0').hitTestable(), findsOneWidget);
    expect(_activePages(active), [0]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion selects the destination immediately', (
    tester,
  ) async {
    final created = <int>[];
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await tester.pumpWidget(
      _harness(selected, created, {}, reducedMotion: true),
    );
    selected.value = 3;
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.text('Page 3').hitTestable(), findsOneWidget);
    expect(created, [0, 3]);
    expect(tester.getRect(_page(3)).left, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('enabling reduced motion cancels the current flight and queue', (
    tester,
  ) async {
    final created = <int>[];
    final active = <int, bool>{};
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await tester.pumpWidget(_harness(selected, created, active));
    selected.value = 3;
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 75));
    selected.value = 1;
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(
      _harness(selected, created, active, reducedMotion: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('Page 1').hitTestable(), findsOneWidget);
    expect(tester.getRect(_page(1)).left, 0);
    expect(created, [0, 3, 1]);
    expect(_activePages(active), [1]);
    expect(tester.takeException(), isNull);
  });
}

Finder _page(int index) => find.byKey(ValueKey('page-$index'));
Finder _field(int index) => find.byKey(ValueKey('field-$index'));
Iterable<int> _activePages(Map<int, bool> active) =>
    active.entries.where((entry) => entry.value).map((entry) => entry.key);

Widget _harness(
  ValueNotifier<int> selected,
  List<int> created,
  Map<int, bool> active, {
  bool reducedMotion = false,
  bool rtl = false,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: ValueListenableBuilder<int>(
          valueListenable: selected,
          builder: (_, index, _) => FlClashTabView(
            selectedIndex: index,
            itemCount: 4,
            builder: (_, index, isActive) {
              active[index] = isActive;
              return _Probe(index: index, created: created);
            },
          ),
        ),
      ),
    ),
  );
}

class _Probe extends StatefulWidget {
  const _Probe({required this.index, required this.created});
  final int index;
  final List<int> created;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  final _controller = TextEditingController();
  @override
  void initState() {
    super.initState();
    widget.created.add(widget.index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    key: ValueKey('page-${widget.index}'),
    child: Column(
      children: [
        Text('Page ${widget.index}'),
        TextField(
          key: ValueKey('field-${widget.index}'),
          controller: _controller,
        ),
      ],
    ),
  );
}
