import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/features/home/pages/chat/widgets/chat_widgets.dart';
import 'package:ui/theme/theme_context.dart';
import 'package:ui/services/app_background_service.dart';
import 'package:ui/widgets/omni_circle_button.dart';

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
  ValueChanged<String>? onAgent,
  VoidCallback? onBack,
  VoidCallback? onPet,
  VoidCallback? onTerminal,
  VoidCallback? onBrowser,
  VoidCallback? onEnvironment,
  VoidCallback? onUpdate,
  VoidCallback? onPure,
  ValueChanged<ChatSurfaceMode>? onMode,
  bool pure = false,
  bool locked = false,
  bool isAgentLoading = false,
  bool translucent = false,
  AppBackgroundVisualProfile visualProfile =
      AppBackgroundVisualProfile.defaultProfile,
  bool isAgentSelected = true,
  ChatSurfaceMode surface = ChatSurfaceMode.normal,
  List<ChatAppBarAction> actions = const [],
}) => DefaultAssetBundle(
  bundle: _SvgTestAssetBundle(),
  child: MaterialApp(
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
            onAcpAgentTap: onAgent,
            onPureChatToggleTap: onPure,
            isPureChatSelected: pure,
            isPureChatToggleLocked: locked,
            isAgentSelected: isAgentSelected,
            isOmniAiSelected: false,
            activeAcpAgentId: selectedAgent,
            acpAgentModes: agents,
            isAgentLoading: isAgentLoading,
            translucent: translucent,
            visualProfile: visualProfile,
            isBrowserEnabled: onBrowser != null,
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

Future<void> _openModes(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('chat-app-bar-pure-chat-button')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'title and mode subtitle replace the island with two circular actions',
    (tester) async {
      var backs = 0;
      await tester.pumpWidget(_app(onBack: () => backs++));
      expect(find.text('Inspect the current workspace'), findsOneWidget);
      expect(find.text('OmniBot Agent'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-app-bar-island')), findsNothing);
      expect(
        tester.getTopLeft(find.text('OmniBot Agent')).dy,
        greaterThan(
          tester.getTopLeft(find.text('Inspect the current workspace')).dy,
        ),
      );
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
    },
  );

  testWidgets(
    'opaque navigation controls keep contrast over a dark custom wallpaper',
    (tester) async {
      await tester.pumpWidget(
        _app(
          translucent: true,
          visualProfile: const AppBackgroundVisualProfile(
            sampledImageLuminance: 0.05,
            effectiveLuminance: 0.05,
            textTone: AppBackgroundTextTone.light,
          ),
        ),
      );
      final context = tester.element(find.byType(ChatAppBar));
      for (final circle in tester.widgetList<OmniCircleButton>(
        find.byType(OmniCircleButton),
      )) {
        expect(circle.foregroundColor, context.omniPalette.textPrimary);
        expect(
          circle.foregroundColor,
          isNot(context.omniPalette.surfacePrimary),
        );
      }
      final mode = find.byKey(const ValueKey('chat-app-bar-pure-chat-button'));
      expect(tester.getSize(mode).height, greaterThanOrEqualTo(48));
      expect(find.byTooltip('Switch chat mode'), findsOneWidget);
    },
  );

  for (final width in [320.0, 390.0, 800.0]) {
    testWidgets('header fits ${width.toInt()} logical pixels with large text', (
      tester,
    ) async {
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
      expect(back.width, 44);
      expect(more.width, 44);
      expect(more.left, greaterThan(back.right));
      await _openModes(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'installed Agent selection uses the existing ACP callback while another is loading',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        _app(onAgent: (value) => selected = value, isAgentLoading: true),
      );
      await _openModes(tester);
      await tester.tap(find.text('Na'));
      await tester.pumpAndSettle();
      expect(selected, 'na-cloud');
      expect(find.text('Na'), findsNothing);
    },
  );

  testWidgets(
    'history selection updates the subtitle on every conversation change',
    (tester) async {
      for (final agent in ['codex-acp', 'na-cloud', 'xiaowan-acp']) {
        await tester.pumpWidget(_app(selectedAgent: agent));
        await tester.pumpAndSettle();
        expect(
          find.text(
            {
              'codex-acp': 'Codex',
              'na-cloud': 'Na',
              'xiaowan-acp': 'OmniBot Agent',
            }[agent]!,
          ),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets(
    'uninstalled and disabled Agents are omitted without blocking the builtin Agent',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        _app(
          agents: const [
            ChatAcpAgentModeOption(
              id: 'missing',
              name: 'Missing',
              installed: false,
            ),
            ChatAcpAgentModeOption(
              id: 'disabled',
              name: 'Disabled',
              enabled: false,
            ),
          ],
          onAgent: (value) => selected = value,
        ),
      );
      await _openModes(tester);
      expect(find.text('Missing'), findsNothing);
      expect(find.text('Disabled'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('chat-app-bar-mode-menu-xiaowan-acp')),
      );
      await tester.pumpAndSettle();
      expect(selected, 'xiaowan-acp');
    },
  );

  testWidgets('pure chat selection respects the existing lock', (tester) async {
    var switches = 0;
    await tester.pumpWidget(_app(onPure: () => switches++));
    await _openModes(tester);
    await tester.tap(
      find.byKey(const ValueKey('chat-app-bar-mode-menu-pure-chat')),
    );
    await tester.pumpAndSettle();
    expect(switches, 1);
    await tester.pumpWidget(
      _app(onPure: () => switches++, isAgentSelected: false, locked: true),
    );
    await _openModes(tester);
    expect(
      find.byKey(const ValueKey('chat-app-bar-mode-menu-pure-chat')),
      findsNothing,
    );
    expect(switches, 1);
  });

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

  testWidgets('a long Agent list remains scrollable and selectable', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      _app(
        agents: [
          for (var i = 0; i < 30; i++)
            ChatAcpAgentModeOption(id: 'agent-$i', name: 'Agent $i'),
        ],
        onAgent: (value) => selected = value,
      ),
    );
    await _openModes(tester);
    await tester.scrollUntilVisible(find.text('Agent 29'), 400);
    await tester.tap(find.text('Agent 29'));
    await tester.pumpAndSettle();
    expect(selected, 'agent-29');
  });
}
