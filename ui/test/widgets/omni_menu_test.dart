import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/omni_menu.dart';

void main() {
  testWidgets('popup ignores disabled actions and returns the selected value', (
    tester,
  ) async {
    String? selected;
    var callbacks = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: PopupMenuButton<String>(
            onSelected: (value) => selected = value,
            itemBuilder: (_) => [
              const OmniPopupMenuItem<String>(
                value: 'disabled',
                enabled: false,
                child: Text('Unavailable'),
              ),
              OmniPopupMenuItem<String>(
                value: 'archive',
                onTap: () => callbacks++,
                child: const Text('Archive'),
              ),
            ],
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unavailable'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(find.text('Archive'), findsOneWidget);
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(selected, 'archive');
    expect(callbacks, 1);
    expect(find.text('Archive'), findsNothing);
  });

  testWidgets('popup retains keyboard activation', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: PopupMenuButton<String>(
            requestFocus: true,
            onSelected: (value) => selected = value,
            itemBuilder: (_) => const [
              OmniPopupMenuItem<String>(value: 'copy', child: Text('Copy')),
            ],
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final ink = tester.widget<InkWell>(
      find.descendant(
        of: find.byType(OmniMenuItem),
        matching: find.byType(InkWell),
      ),
    );
    expect(ink.canRequestFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, 'copy');
  });

  testWidgets('overlay rows leave dismissal to their owner', (tester) async {
    var enabled = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SizedBox(
              width: 280,
              child: OmniMenuSurface(
                child: OmniMenuItem(
                  onTap: () => setState(() => enabled = !enabled),
                  label: 'Show model',
                  selected: enabled,
                  trailing: Switch(
                    value: enabled,
                    onChanged: (value) => setState(() => enabled = value),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(enabled, isTrue);
    await tester.tap(find.text('Show model'));
    await tester.pumpAndSettle();
    expect(enabled, isFalse);
    expect(find.byType(OmniMenuSurface), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
