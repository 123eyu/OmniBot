import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ui/widgets/agent_brand_icon.dart';
import 'package:ui/features/home/pages/chat/widgets/chat_widgets.dart';
import 'package:ui/theme/theme_context.dart';
import 'package:ui/services/app_background_service.dart';
import 'package:ui/widgets/omni_circle_button.dart';
import 'package:ui/widgets/flclash/popup.dart';

class _SvgTestAssetBundle extends CachingAssetBundle {
  final _bytes = Uint8List.fromList(
    utf8.encode(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
      '<rect width="24" height="24" fill="#000"/></svg>',
    ),
  );
  @override
  Future<ByteData> load(String key) async => ByteData.view(_bytes.buffer);
  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      utf8.decode(_bytes);
}

Widget _app({
  String? selectedAgent = 'xiaowan-acp',
  List<ChatAcpAgentModeOption> agents = const [
    ChatAcpAgentModeOption(id: 'xiaowan-acp', name: 'OmniBot Agent'),
    ChatAcpAgentModeOption(id: 'codex-acp', name: 'Codex'),
    ChatAcpAgentModeOption(id: 'na-cloud', name: 'Na'),
  ],
  VoidCallback? onBack,
  VoidCallback? onPet,
  VoidCallback? onTerminal,
  VoidCallback? onBrowser,
  VoidCallback? onEnvironment,
  VoidCallback? onUpdate,
  ValueChanged<ChatSurfaceMode>? onMode,
  bool pure = false,
  bool showTerminalActions = true,
  bool translucent = false,
  AppBackgroundVisualProfile visualProfile =
      AppBackgroundVisualProfile.defaultProfile,
  ChatSurfaceMode surface = ChatSurfaceMode.normal,
  List<ChatAppBarAction> actions = const [],
  VisualDensity? buttonDensity,
}) => DefaultAssetBundle(
  bundle: _SvgTestAssetBundle(),
  child: MaterialApp(
    theme: ThemeData(
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(visualDensity: buttonDensity),
      ),
    ),
    home: Scaffold(
      body: Column(
        children: [
          ChatAppBar(
            title: 'Inspect the current workspace',
            onMenuTap: onBack ?? () {},
            onPetTap: onPet,
            onTerminalTap: onTerminal ?? () {},
            onBrowserTap: onBrowser ?? () {},
            onTerminalEnvironmentTap: (_) => onEnvironment?.call(),
            onDisplayLayerChanged: (_) {},
            activeMode: surface,
            onModeChanged: onMode ?? (_) {},
            isPureChatSelected: pure,
            activeAcpAgentId: selectedAgent,
            acpAgentModes: agents,
            translucent: translucent,
            visualProfile: visualProfile,
            isBrowserEnabled: onBrowser != null,
            showTerminalActions: showTerminalActions,
            showAppUpdateIndicator: onUpdate != null,
            onAppUpdateTap: onUpdate,
            actions: actions,
          ),
        ],
      ),
    ),
  ),
);

Future<void> _openActions(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('chat-app-bar-more-button')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'popup circle measures the visible surface with compact density',
    (tester) async {
      await tester.pumpWidget(_app(buttonDensity: VisualDensity.compact));
      final trigger = find.byKey(const ValueKey('chat-app-bar-more-button'));
      final circle = find.descendant(
        of: trigger,
        matching: find.byWidgetPredicate(
          (widget) => widget is Material && widget.shape is CircleBorder,
        ),
      );
      final actual = tester.getRect(circle);
      expect(actual.size, const Size.square(40));
      expect(tester.getSize(trigger), const Size.square(40));
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      final transition = tester.widget<FlClashPopupTransition>(
        find.byType(FlClashPopupTransition),
      );
      expect(transition.anchor, actual);
      expect(
        transition.source!.image.value!.width / tester.view.devicePixelRatio,
        actual.width,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('menu captures the visible circle and commits after returning', (
    tester,
  ) async {
    var terminals = 0;
    await tester.pumpWidget(_app(onTerminal: () => terminals++));
    final trigger = find.byKey(const ValueKey('chat-app-bar-more-button'));
    final touchBounds = tester.getRect(trigger);
    final circleBounds = tester.getRect(
      find.descendant(
        of: trigger,
        matching: find.byWidgetPredicate(
          (widget) => widget is Material && widget.shape is CircleBorder,
        ),
      ),
    );
    expect(touchBounds.size, const Size.square(48));
    expect(circleBounds.size, const Size.square(40));
    // The extra touch area continues to open the menu.
    await tester.tapAt(touchBounds.centerLeft + const Offset(1, 0));
    await tester.pumpAndSettle();
    final transition = tester.widget<FlClashPopupTransition>(
      find.byType(FlClashPopupTransition),
    );
    expect(transition.anchor, circleBounds);
    final pixelRatio = tester.view.devicePixelRatio;
    expect(transition.source!.image.value!.width / pixelRatio, 40);
    expect(transition.source!.image.value!.height / pixelRatio, 40);
    await tester.tap(find.text('Terminal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(terminals, 0);
    await tester.pumpAndSettle();
    expect(terminals, 1);
    expect(tester.getRect(trigger), touchBounds);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mode mark precedes the title without a switch interaction', (
    tester,
  ) async {
    var backs = 0;
    await tester.pumpWidget(_app(onBack: () => backs++));
    await tester.pumpAndSettle();
    final title = find.byKey(const ValueKey('chat-app-bar-title'));
    final mark = find.byKey(const ValueKey('chat-app-bar-mode-icon'));
    expect(find.text('Inspect the current workspace'), findsOneWidget);
    expect(find.text('OmniBot Agent'), findsNothing);
    expect(
      find.byKey(const ValueKey('chat-app-bar-pure-chat-button')),
      findsNothing,
    );
    expect(find.byTooltip('Switch chat mode'), findsNothing);
    expect(tester.getRect(mark).right, lessThan(tester.getRect(title).left));
    expect(tester.getCenter(mark).dy, closeTo(tester.getCenter(title).dy, .1));
    expect(tester.widget<Text>(title).style!.fontSize, 17);
    await tester.tap(mark, warnIfMissed: false);
    await tester.tap(title, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuItem<String>), findsNothing);
    final context = tester.element(find.byType(ChatAppBar));
    expect(
      tester
          .widget<ColoredBox>(
            find.byKey(const ValueKey('chat-app-bar-background')),
          )
          .color,
      context.omniPalette.pageBackground,
    );
    await tester.tap(find.byKey(const ValueKey('chat-app-bar-menu-button')));
    expect(backs, 1);
  });

  testWidgets('compact controls retain contrast over a dark custom wallpaper', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        translucent: true,
        visualProfile: const AppBackgroundVisualProfile(
          sampledImageLuminance: .05,
          effectiveLuminance: .05,
          textTone: AppBackgroundTextTone.light,
        ),
      ),
    );
    final context = tester.element(find.byType(ChatAppBar));
    for (final circle in tester.widgetList<OmniCircleButton>(
      find.byType(OmniCircleButton),
    )) {
      expect(circle.foregroundColor, context.omniPalette.textPrimary);
      expect(circle.foregroundColor, isNot(context.omniPalette.surfacePrimary));
      expect(circle.size, 40);
      expect(circle.tapTargetSize, MaterialTapTargetSize.padded);
      final button = find.byWidget(circle);
      expect(tester.getSize(button), const Size.square(48));
      expect(
        tester.getSize(
          find.descendant(
            of: button,
            matching: find.byWidgetPredicate(
              (widget) => widget is Material && widget.shape is CircleBorder,
            ),
          ),
        ),
        const Size.square(40),
      );
      expect(
        tester.getSize(
          find.descendant(of: button, matching: find.byType(Icon)),
        ),
        const Size.square(20),
      );
    }
    expect(find.byTooltip('Switch chat mode'), findsNothing);
  });

  for (final width in [320.0, 390.0, 800.0]) {
    testWidgets(
      'compact header fits ${width.toInt()} logical pixels with large text',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(_app());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final back = tester.getRect(
          find.byKey(const ValueKey('chat-app-bar-menu-button')),
        );
        final more = tester.getRect(
          find.byKey(const ValueKey('chat-app-bar-more-button')),
        );
        expect(back.width, greaterThanOrEqualTo(44));
        expect(more.width, greaterThanOrEqualTo(44));
        expect(more.left, greaterThan(back.right));
        expect(
          tester.getSize(find.byType(ChatAppBar)).height,
          lessThanOrEqualTo(64),
        );
      },
    );
  }

  testWidgets(
    'history selection updates the actual Agent mark without a selector',
    (tester) async {
      for (final agent in [
        'xiaowan-acp',
        'na-cloud',
        'codex-acp',
        'custom-harness',
      ]) {
        await tester.pumpWidget(_app(selectedAgent: agent));
        await tester.pumpAndSettle();
        expect(
          tester.widget<AgentBrandIcon>(find.byType(AgentBrandIcon)).agentId,
          agent,
        );
        if (agent == 'na-cloud') expect(find.text('N'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('chat-app-bar-pure-chat-button')),
          findsNothing,
        );
        expect(find.byType(PopupMenuItem<String>), findsNothing);
      }
    },
  );

  testWidgets(
    'pure chat has its own static mark even with a remembered Agent',
    (tester) async {
      await tester.pumpWidget(_app(pure: true, selectedAgent: 'na-cloud'));
      await tester.pumpAndSettle();
      expect(find.byType(AgentBrandIcon), findsNothing);
      expect(find.byIcon(LucideIcons.messageCircle), findsOneWidget);
      expect(find.text('Pure chat'), findsNothing);
      await _openActions(tester);
      expect(find.text('Pure chat'), findsNothing);
      expect(find.text('Na'), findsNothing);
      expect(find.text('OmniBot Agent'), findsNothing);
    },
  );

  testWidgets(
    'terminal visibility leaves workspace and browser actions independent',
    (tester) async {
      var browsers = 0;
      await tester.pumpWidget(
        _app(
          selectedAgent: 'na-cloud',
          showTerminalActions: false,
          onBrowser: () => browsers++,
        ),
      );
      await _openActions(tester);
      expect(find.text('Terminal'), findsNothing);
      expect(find.text('Environment variables'), findsNothing);
      expect(find.text('Workspace files'), findsOneWidget);
      await tester.tap(find.text('Browser'));
      await tester.pumpAndSettle();
      expect(browsers, 1);
    },
  );

  testWidgets(
    'all auxiliary actions are menu entries and invoke only their owner',
    (tester) async {
      final invoked = <String>[];
      await tester.pumpWidget(
        _app(
          onPet: () => invoked.add('pet'),
          onTerminal: () => invoked.add('terminal'),
          onBrowser: () => invoked.add('browser'),
          onEnvironment: () => invoked.add('environment'),
          onUpdate: () => invoked.add('update'),
          actions: [
            ChatAppBarAction(
              label: 'Model & settings',
              icon: Icons.tune,
              onSelected: (anchor) {
                expect(anchor.mounted, isTrue);
                invoked.add('model');
              },
            ),
          ],
        ),
      );
      for (final entry in {
        'Model & settings': 'model',
        'Terminal': 'terminal',
        'Environment variables': 'environment',
        'Browser': 'browser',
        'Show pet': 'pet',
        'Check for updates': 'update',
      }.entries) {
        expect(find.text(entry.key), findsNothing);
        await _openActions(tester);
        await tester.ensureVisible(find.text(entry.key));
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();
        expect(invoked.last, entry.value);
      }
      expect(invoked, [
        'model',
        'terminal',
        'environment',
        'browser',
        'pet',
        'update',
      ]);
    },
  );

  testWidgets(
    'workspace entry delegates both directions without visible capsule',
    (tester) async {
      ChatSurfaceMode? requested;
      await tester.pumpWidget(_app(onMode: (value) => requested = value));
      await _openActions(tester);
      await tester.tap(find.text('Workspace files'));
      await tester.pumpAndSettle();
      expect(requested, ChatSurfaceMode.workspace);
      await tester.pumpWidget(
        _app(
          surface: ChatSurfaceMode.workspace,
          onMode: (value) => requested = value,
        ),
      );
      await _openActions(tester);
      await tester.tap(find.text('Return to conversation'));
      await tester.pumpAndSettle();
      expect(requested, ChatSurfaceMode.normal);
    },
  );

  testWidgets('system back dismisses the options menu without navigating', (
    tester,
  ) async {
    var backs = 0;
    await tester.pumpWidget(_app(onBack: () => backs++));
    await _openActions(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Terminal'), findsNothing);
    expect(backs, 0);
    expect(find.byType(ChatAppBar), findsOneWidget);
  });
}
