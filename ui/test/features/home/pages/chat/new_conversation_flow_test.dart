import 'dart:async';

import 'package:android_file_picker/android_file_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ui/features/home/pages/chat/chat_page.dart';
import 'package:ui/features/home/pages/chat/services/chat_conversation_runtime_coordinator.dart';
import 'package:ui/features/home/pages/chat/widgets/new_conversation_mode_selector.dart';
import 'package:ui/features/home/pages/command_overlay/widgets/chat_input_area.dart';
import 'package:ui/l10n/generated/app_localizations.dart';
import 'package:ui/l10n/legacy_text_localizer.dart';
import 'package:ui/models/conversation_model.dart';
import 'package:ui/models/conversation_thread_target.dart';
import 'package:ui/services/storage_service.dart';
import 'package:ui/theme/app_theme.dart';

class _DraftFilePicker extends FilePickerPlatform {
  List<PlatformFile> nextFiles = [];

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => nextFiles;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const assistChannel = MethodChannel('cn.com.omnimind.bot/AssistCoreEvent');
  const agentChannel = MethodChannel('cn.com.omnimind.bot/AgentRuntime');
  const otherChannels = [
    'cn.com.omnimind.bot/AgentRuntimeEvents',
    'cn.com.omnimind.bot/OmniLinkEvents',
    'cn.com.omnimind.bot/SpecialPermissionEvent',
    'cn.com.omnimind.bot/SpecialPermissionEvents',
    'cn.com.omnimind.bot/VoicePlayback',
    'cn.com.omnimind.bot/VoicePlaybackEvents',
    'cn.com.omnimind.bot/overlay',
    'cn.com.omnimind.bot/app_update',
    'cn.com.omnimind.bot/app_state',
    'cn.com.omnimind.bot/PluginPlatform',
  ];
  final coordinator = ChatConversationRuntimeCoordinator.instance;
  late List<MethodCall> assistCalls;
  late List<MethodCall> agentCalls;
  late List<Map<String, Object?>> conversations;
  late _DraftFilePicker picker;
  late FilePickerPlatform originalPicker;
  Completer<void>? initializeGate;
  var allowConversationCreation = false;

  const agents = [
    {
      'id': 'xiaowan-acp',
      'name': '小万',
      'enabled': true,
      'installed': true,
      'status': 'online',
    },
    {
      'id': 'codex-acp',
      'name': 'Codex',
      'enabled': true,
      'installed': true,
      'status': 'online',
    },
    {
      'id': 'na-cloud',
      'name': 'Na',
      'enabled': true,
      'installed': true,
      'status': 'online',
    },
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    LegacyTextLocalizer.setResolvedLocale(const Locale('zh'));
    coordinator.resetForTest();
    originalPicker = FilePickerPlatform.instance;
    picker = _DraftFilePicker();
    FilePickerPlatform.instance = picker;
    initializeGate = null;
    allowConversationCreation = false;
    assistCalls = [];
    agentCalls = [];
    conversations = [];
    for (final channel in otherChannels) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), (_) async {
        return null;
      });
    }
    messenger.setMockMethodCallHandler(assistChannel, (call) async {
      assistCalls.add(call);
      switch (call.method) {
        case 'getConversations':
          return conversations;
        case 'getConversationMessagesPaged':
          return {'messages': <Object?>[], 'hasMore': false};
        case 'listModelProviderProfiles':
          return {'profiles': <Object?>[], 'editingProfileId': ''};
        case 'getSceneCatalog':
        case 'getSceneModelBindings':
        case 'getScheduledTasks':
          return <Object?>[];
        case 'setCurrentConversationId':
          await initializeGate?.future;
          return 'SUCCESS';
        case 'createConversation':
          return allowConversationCreation ? 901 : null;
        case 'updateConversation':
          return 'SUCCESS';
        case 'getWorkspaceLongMemory':
          return {'content': ''};
      }
      return null;
    });
    messenger.setMockMethodCallHandler(agentChannel, (call) async {
      agentCalls.add(call);
      switch (call.method) {
        case 'agent/list':
          return {'selectedAgentId': 'xiaowan-acp', 'agents': agents};
        case 'status':
          return {
            'ready': false,
            'connected': false,
            'activeAgentId': 'xiaowan-acp',
            'activeAgentName': '小万',
          };
        case 'session/new':
          return {'sessionId': 'new-draft-session'};
        case 'session/prompt':
          return {'sessionId': 'new-draft-session', 'stopReason': 'end_turn'};
      }
      return <String, Object?>{};
    });
  });

  tearDown(() {
    coordinator.resetForTest();
    FilePickerPlatform.instance = originalPicker;
    LegacyTextLocalizer.clearResolvedLocale();
    messenger.setMockMethodCallHandler(assistChannel, null);
    messenger.setMockMethodCallHandler(agentChannel, null);
    for (final channel in otherChannels) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), null);
    }
  });

  Future<void> pumpChat(
    WidgetTester tester,
    ConversationThreadTarget target, {
    bool tour = false,
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          navigatorKey: navigatorKey,
          theme: AppTheme.lightTheme,
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChatPage(threadTarget: target, showFirstUseTour: tour),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ChatInputArea composer(WidgetTester tester) =>
      tester.widget<ChatInputArea>(find.byType(ChatInputArea));

  NewConversationModeSelector selector(WidgetTester tester) =>
      tester.widget<NewConversationModeSelector>(
        find.byType(NewConversationModeSelector),
      );

  Future<void> chooseMode(WidgetTester tester, String id) async {
    await tester.tap(
      find.byKey(const ValueKey('new-conversation-mode-selector')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('new-conversation-mode-option-$id')));
    await tester.pumpAndSettle();
  }

  Future<void> attachFile(WidgetTester tester, String name) async {
    picker.nextFiles = [
      AndroidPlatformFile(
        name: name,
        uri: Uri.parse('content://documents/$name'),
        bytesLength: 42,
      ),
    ];
    await composer(tester).onPickAttachment!();
    await tester.pumpAndSettle();
  }

  void expectNoSessionAdmission() {
    expect(
      agentCalls.where(
        (call) => const {
          'agent/select',
          'session/new',
          'session/prompt',
        }.contains(call.method),
      ),
      isEmpty,
    );
    expect(
      assistCalls.where((call) => call.method == 'createConversation'),
      isEmpty,
    );
  }

  Future<void> disposeChat(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'existing history has no new-conversation selector or autofocus',
    (tester) async {
      conversations = [
        {
          'id': 701,
          'title': '已有对话',
          'mode': 'chat_only',
          'status': 1,
          'messageCount': 0,
          'createdAt': 1000,
          'updatedAt': 2000,
        },
      ];
      await pumpChat(
        tester,
        const ConversationThreadTarget.existing(
          conversationId: 701,
          mode: ConversationMode.chatOnly,
        ),
      );
      expect(find.byType(ChatInputArea), findsOneWidget);
      expect(
        find.byKey(const ValueKey('new-conversation-mode-selector')),
        findsNothing,
      );
      expect(composer(tester).focusNode.hasFocus, isFalse);
      expect(
        assistCalls.where((call) => call.method == 'createConversation'),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await disposeChat(tester);
    },
  );

  for (final agentId in ['xiaowan-acp', 'codex-acp']) {
    testWidgets('new $agentId draft selects its target and focuses once', (
      tester,
    ) async {
      await pumpChat(
        tester,
        ConversationThreadTarget.newConversation(agentId: agentId),
      );

      expect(selector(tester).selectedId, agentId);
      expect(composer(tester).focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      expectNoSessionAdmission();

      composer(tester).focusNode.unfocus();
      composer(tester).controller.text = '仍在编辑草稿';
      await tester.pumpAndSettle();
      expect(composer(tester).focusNode.hasFocus, isFalse);
      expect(selector(tester).selectedId, agentId);
      await disposeChat(tester);
    });
  }

  testWidgets(
    'Agent switching preserves edits and attachment changes in flight',
    (tester) async {
      await pumpChat(
        tester,
        const ConversationThreadTarget.newConversation(agentId: 'xiaowan-acp'),
      );
      composer(tester).controller.text = '切换前的草稿';
      await attachFile(tester, 'old.pdf');
      final oldAttachmentId = composer(tester).attachments.single.id;
      initializeGate = Completer<void>();
      await chooseMode(tester, 'codex-acp');

      expect(selector(tester).enabled, isFalse);
      expect(composer(tester).controller.text, '切换前的草稿');
      expect(composer(tester).attachments.single.id, oldAttachmentId);
      const editedValue = TextEditingValue(
        text: '等待期间继续编辑的草稿',
        selection: TextSelection(baseOffset: 2, extentOffset: 7),
      );
      composer(tester).controller.value = editedValue;
      composer(tester).onRemoveAttachment!(oldAttachmentId);
      await attachFile(tester, 'latest.pdf');
      final latestAttachment = composer(tester).attachments.single;
      expectNoSessionAdmission();

      initializeGate!.complete();
      await tester.pumpAndSettle();
      expect(selector(tester).selectedId, 'codex-acp');
      expect(selector(tester).enabled, isTrue);
      expect(composer(tester).controller.value, editedValue);
      expect(composer(tester).attachments.single.id, latestAttachment.id);
      expect(composer(tester).attachments.single.name, 'latest.pdf');
      expectNoSessionAdmission();
      await disposeChat(tester);
    },
  );

  testWidgets('pure chat and Agent round trip carries the same unsent draft', (
    tester,
  ) async {
    await pumpChat(
      tester,
      const ConversationThreadTarget.newConversation(agentId: 'codex-acp'),
    );
    const draft = TextEditingValue(
      text: '带附件的草稿',
      selection: TextSelection.collapsed(offset: 3),
    );
    composer(tester).controller.value = draft;
    await attachFile(tester, 'draft.pdf');
    final attachmentId = composer(tester).attachments.single.id;

    await chooseMode(tester, kNewConversationPureChatModeId);
    expect(selector(tester).selectedId, kNewConversationPureChatModeId);
    expect(composer(tester).controller.value, draft);
    expect(composer(tester).attachments.single.id, attachmentId);
    expect(
      (assistCalls
              .lastWhere((call) => call.method == 'setCurrentConversationId')
              .arguments
          as Map)['mode'],
      ConversationMode.chatOnly.storageValue,
    );

    await chooseMode(tester, 'xiaowan-acp');
    expect(selector(tester).selectedId, 'xiaowan-acp');
    expect(composer(tester).controller.value, draft);
    expect(composer(tester).attachments.single.id, attachmentId);
    expect(
      (assistCalls
              .lastWhere((call) => call.method == 'setCurrentConversationId')
              .arguments
          as Map)['mode'],
      ConversationMode.agent.storageValue,
    );
    expectNoSessionAdmission();
    await disposeChat(tester);
  });

  testWidgets('first-use tour does not show selector or focus the composer', (
    tester,
  ) async {
    await pumpChat(
      tester,
      const ConversationThreadTarget.newConversation(agentId: 'xiaowan-acp'),
      tour: true,
    );
    expect(find.byType(NewConversationModeSelector), findsNothing);
    expect(composer(tester).focusNode.hasFocus, isFalse);
    expectNoSessionAdmission();
    await disposeChat(tester);
  });

  testWidgets(
    'bootstrap completion beneath another route does not steal focus',
    (tester) async {
      initializeGate = Completer<void>();
      final navigator = GlobalKey<NavigatorState>();
      await pumpChat(
        tester,
        const ConversationThreadTarget.newConversation(agentId: 'xiaowan-acp'),
        navigatorKey: navigator,
      );
      final inputFocus = composer(tester).focusNode;
      expect(inputFocus.hasFocus, isFalse);
      unawaited(
        navigator.currentState!.push<void>(
          MaterialPageRoute(builder: (_) => const Scaffold(body: Text('覆盖页面'))),
        ),
      );
      await tester.pumpAndSettle();
      initializeGate!.complete();
      await tester.pumpAndSettle();
      expect(inputFocus.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(inputFocus.hasFocus, isFalse);
      expectNoSessionAdmission();
      await disposeChat(tester);
    },
  );

  testWidgets('disposing during bootstrap does not request composer focus', (
    tester,
  ) async {
    initializeGate = Completer<void>();
    await pumpChat(
      tester,
      const ConversationThreadTarget.newConversation(agentId: 'xiaowan-acp'),
    );
    await disposeChat(tester);
    initializeGate!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.testTextInput.isVisible, isFalse);
    expectNoSessionAdmission();
  });

  testWidgets('send waits for Agent switch and submits once to the new Agent', (
    tester,
  ) async {
    allowConversationCreation = true;
    await pumpChat(
      tester,
      const ConversationThreadTarget.newConversation(agentId: 'xiaowan-acp'),
    );
    composer(tester).controller.text = '切换后发送给 Codex';
    initializeGate = Completer<void>();
    await chooseMode(tester, 'codex-acp');
    composer(tester).onSendMessage();
    composer(tester).onSendMessage();
    await tester.pumpAndSettle();
    expectNoSessionAdmission();

    initializeGate!.complete();
    await tester.pumpAndSettle();
    final creations = assistCalls
        .where((call) => call.method == 'createConversation')
        .toList();
    final prompts = agentCalls
        .where((call) => call.method == 'session/prompt')
        .toList();
    expect(creations, hasLength(1));
    expect((creations.single.arguments as Map)['agentId'], 'codex-acp');
    expect(prompts, hasLength(1));
    expect((prompts.single.arguments as Map)['agentId'], 'codex-acp');
    expect((prompts.single.arguments as Map)['text'], '切换后发送给 Codex');
    expect(agentCalls.where((call) => call.method == 'agent/select'), isEmpty);
    expect(find.byType(NewConversationModeSelector), findsNothing);
    await disposeChat(tester);
  });

  testWidgets('send during initial bootstrap retains input for its target', (
    tester,
  ) async {
    allowConversationCreation = true;
    initializeGate = Completer<void>();
    await pumpChat(
      tester,
      const ConversationThreadTarget.newConversation(agentId: 'codex-acp'),
    );
    composer(tester).controller.text = '初始化期间输入并发送';
    composer(tester).onSendMessage();
    await tester.pumpAndSettle();
    expectNoSessionAdmission();

    initializeGate!.complete();
    await tester.pumpAndSettle();
    final prompts = agentCalls
        .where((call) => call.method == 'session/prompt')
        .toList();
    expect(prompts, hasLength(1));
    expect((prompts.single.arguments as Map)['agentId'], 'codex-acp');
    expect((prompts.single.arguments as Map)['text'], '初始化期间输入并发送');
    expect(composer(tester).focusNode.hasFocus, isFalse);
    await disposeChat(tester);
  });

  testWidgets(
    'initial-message entry sends once without showing draft controls',
    (tester) async {
      allowConversationCreation = true;
      await pumpChat(
        tester,
        const ConversationThreadTarget.newConversation(
          agentId: 'codex-acp',
          initialMessage: '来自已有入口的任务',
          requestKey: 'initial-task',
        ),
      );
      final prompts = agentCalls
          .where((call) => call.method == 'session/prompt')
          .toList();
      expect(prompts, hasLength(1));
      expect((prompts.single.arguments as Map)['agentId'], 'codex-acp');
      expect((prompts.single.arguments as Map)['text'], '来自已有入口的任务');
      expect(find.byType(NewConversationModeSelector), findsNothing);
      expect(composer(tester).focusNode.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      await disposeChat(tester);
    },
  );
}
