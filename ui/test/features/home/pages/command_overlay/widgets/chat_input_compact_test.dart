import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/features/home/pages/chat/widgets/acp_config_button.dart';
import 'package:ui/features/home/pages/command_overlay/widgets/chat_input_area.dart';
import 'package:ui/theme/app_theme.dart';

void main() {
  final shell = find.byKey(const ValueKey('chat-minimal-composer'));
  final plus = find.byKey(
    const ValueKey('chat-input-add-or-cancel-edit-button'),
  );
  final send = find.byKey(const ValueKey('chat-input-send-or-stop-button'));

  testWidgets(
    'collapsed model is hidden without disposing its configuration owner',
    (tester) async {
      final fixture = _ComposerFixture(tester);
      final configKey = GlobalKey<AcpConfigButtonState>();
      var loads = 0;
      await fixture.pump(
        runtimeConfigButton: AcpConfigButton(
          key: configKey,
          modelLabel: 'provider/gpt-5.4',
          isRunning: false,
          load: () async {
            loads++;
            return {};
          },
          write: (_, _, _) async => {},
        ),
      );
      final owner = configKey.currentState;
      final modelRegion = find.byKey(
        const ValueKey('chat-input-model-visibility'),
      );
      expect(tester.getSize(modelRegion).width, 0);
      expect(
        find.byKey(const ValueKey('chat-acp-config-button')).hitTestable(),
        findsNothing,
      );
      expect(loads, 0);
      fixture.focus.requestFocus();
      await tester.pumpAndSettle();
      expect(tester.getSize(modelRegion).width, greaterThan(90));
      expect(
        find.byKey(const ValueKey('chat-acp-config-button')).hitTestable(),
        findsOneWidget,
      );
      expect(find.text('gpt-5.4'), findsOneWidget);
      expect(configKey.currentState, same(owner));
      fixture.focus.unfocus();
      await tester.pumpAndSettle();
      expect(tester.getSize(modelRegion).width, 0);
      expect(configKey.currentState, same(owner));
      fixture.focus.requestFocus();
      await tester.pumpAndSettle();
      expect(find.text('gpt-5.4'), findsOneWidget);
      expect(configKey.currentState, same(owner));
      expect(loads, 0);
    },
  );

  testWidgets('focus animates two rows without replacing the draft editor', (
    tester,
  ) async {
    final fixture = _ComposerFixture(tester);
    await fixture.pump();
    final editor = tester.state<EditableTextState>(find.byType(EditableText));
    expect(tester.getSize(shell).height, 50);
    fixture.controller.value = const TextEditingValue(
      text: 'Unsent draft',
      selection: TextSelection.collapsed(offset: 6),
      composing: TextRange(start: 0, end: 6),
    );
    fixture.focus.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getSize(shell).height, greaterThan(50));
    expect(tester.getSize(shell).height, lessThan(97));
    expect(
      tester.state<EditableTextState>(find.byType(EditableText)),
      same(editor),
    );
    expect(fixture.controller.selection.baseOffset, 6);
    expect(
      fixture.controller.value.composing,
      const TextRange(start: 0, end: 6),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(shell).height, 97);
    fixture.controller.text = 'One\nTwo\nThree\nFour';
    await tester.pumpAndSettle();
    expect(tester.getSize(shell).height, greaterThan(140));
    fixture.focus.unfocus();
    await tester.pumpAndSettle();
    expect(tester.getSize(shell).height, 50);
    expect(fixture.controller.text, 'One\nTwo\nThree\nFour');
    expect(
      tester.state<EditableTextState>(find.byType(EditableText)),
      same(editor),
    );
  });

  testWidgets('temporary model override follows the expanded model controls', (
    tester,
  ) async {
    final fixture = _ComposerFixture(tester);
    var clearCount = 0;
    await fixture.pump(
      selectedModelOverrideId: 'provider/temporary-model',
      onClearSelectedModelOverride: () => clearCount++,
    );
    final region = find.byKey(
      const ValueKey('chat-input-model-override-visibility'),
    );
    expect(tester.getSize(region).height, 0);
    expect(tester.getSize(shell).height, 50);
    fixture.focus.requestFocus();
    await tester.pumpAndSettle();
    expect(tester.getSize(region).height, greaterThan(20));
    expect(
      find.text('@provider/temporary-model').hitTestable(),
      findsOneWidget,
    );
    fixture.focus.unfocus();
    await tester.pumpAndSettle();
    expect(tester.getSize(region).height, 0);
    expect(tester.getSize(shell).height, 50);
    fixture.focus.requestFocus();
    await tester.pumpAndSettle();
    expect(
      find.text('@provider/temporary-model').hitTestable(),
      findsOneWidget,
    );
    expect(clearCount, 0);
  });

  testWidgets('focus animation reverses and reduced motion is immediate', (
    tester,
  ) async {
    final fixture = _ComposerFixture(tester);
    await fixture.pump();
    fixture.focus.requestFocus();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final intermediate = tester.getSize(shell).height;
    fixture.focus.unfocus();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.getSize(shell).height, lessThan(intermediate));
    await tester.pumpAndSettle();
    expect(tester.getSize(shell).height, 50);
    final editor = tester.state<EditableTextState>(find.byType(EditableText));
    await fixture.pump(disableAnimations: true);
    expect(
      tester.state<EditableTextState>(find.byType(EditableText)),
      same(editor),
    );
    fixture.focus.requestFocus();
    await tester.pump();
    await tester
        .pump(); // Flush focus notification without advancing animation time.
    expect(tester.getSize(shell).height, 97);
    fixture.focus.unfocus();
    await tester.pump();
    await tester.pump();
    expect(tester.getSize(shell).height, 50);
  });

  testWidgets('multiline draft height interpolates on focus and blur', (
    tester,
  ) async {
    final fixture = _ComposerFixture(tester);
    await fixture.pump();
    fixture.controller.text = 'One\nTwo\nThree\nFour';
    await tester.pumpAndSettle();
    final editor = tester.state<EditableTextState>(find.byType(EditableText));
    expect(tester.getSize(shell).height, 50);
    fixture.focus.requestFocus();
    await tester.pump();
    await tester.pump();
    expect(tester.getSize(shell).height, 50);
    await tester.pump(const Duration(milliseconds: 80));
    final midpoint = tester.getSize(shell).height;
    expect(midpoint, greaterThan(50));
    await tester.pumpAndSettle();
    final expandedHeight = tester.getSize(shell).height;
    expect(midpoint, lessThan(expandedHeight));
    expect(expandedHeight, greaterThan(140));
    fixture.focus.unfocus();
    await tester.pump();
    await tester.pump();
    expect(tester.getSize(shell).height, expandedHeight);
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getSize(shell).height, lessThan(expandedHeight));
    expect(tester.getSize(shell).height, greaterThan(50));
    await tester.pumpAndSettle();
    expect(tester.getSize(shell).height, 50);
    expect(
      tester.state<EditableTextState>(find.byType(EditableText)),
      same(editor),
    );
  });

  testWidgets(
    'plus menu preserves focus and delegates photos, files and permissions',
    (tester) async {
      final fixture = _ComposerFixture(tester);
      var photos = 0;
      var files = 0;
      AgentPermissionMode? mode;
      await fixture.pump(
        onPickImages: () async => photos++,
        onPickAttachment: () async => files++,
        onPermission: (value) => mode = value,
      );
      fixture.controller.text = 'Keep this';
      fixture.focus.requestFocus();
      await tester.pumpAndSettle();
      final editor = tester.state<EditableTextState>(find.byType(EditableText));
      await tester.tap(plus);
      await tester.pumpAndSettle();
      expect(fixture.focus.hasFocus, isTrue);
      expect(tester.getSize(shell).height, 97);
      await tester.tap(find.byKey(const ValueKey('chat-input-add-images')));
      await tester.pumpAndSettle();
      expect(photos, 1);
      await tester.tap(plus);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-input-add-files')));
      await tester.pumpAndSettle();
      expect(files, 1);
      await tester.tap(plus);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('chat-input-add-permissions')),
      );
      await tester.pumpAndSettle();
      expect(fixture.focus.hasFocus, isTrue);
      expect(tester.getSize(shell).height, 97);
      expect(
        find.byKey(
          const ValueKey('chat-input-agent-permission-option-autoReview'),
        ),
        findsNothing,
      );
      await tester.tap(
        find.byKey(
          const ValueKey('chat-input-agent-permission-option-readOnly'),
        ),
      );
      await tester.pumpAndSettle();
      expect(mode, AgentPermissionMode.readOnly);
      expect(fixture.controller.text, 'Keep this');
      expect(
        tester.state<EditableTextState>(find.byType(EditableText)),
        same(editor),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('native picker keeps expanded layout until the picker returns', (
    tester,
  ) async {
    final fixture = _ComposerFixture(tester);
    final picker = Completer<void>();
    await fixture.pump(onPickImages: () => picker.future);
    fixture.focus.requestFocus();
    await tester.pumpAndSettle();
    await tester.tap(plus);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-input-add-images')));
    await tester.pumpAndSettle();
    fixture.focus.unfocus();
    await tester.pumpAndSettle();
    expect(tester.getSize(shell).height, 97);
    picker.complete();
    await tester.pumpAndSettle();
    expect(tester.getSize(shell).height, 50);
  });

  testWidgets(
    'model popup and shared selector handoff keep the layout stable',
    (tester) async {
      final fixture = _ComposerFixture(tester);
      final selection = Completer<void>();
      final visibility = <bool>[];
      var modelSelections = 0;
      var configLoads = 0;
      await fixture.pump(
        runtimeConfigButton: AcpConfigButton(
          modelLabel: 'provider/gpt-5.4',
          isRunning: false,
          onVisibilityChanged: (value) {
            visibility.add(value);
            fixture.key.currentState!.setAuxiliaryPopupVisible(value);
          },
          load: () async {
            configLoads++;
            return {
              'sessionId': 'session-a',
              'configOptions': [
                {
                  'id': 'model',
                  'category': 'model',
                  'type': 'select',
                  'currentValue': 'gpt-5.4',
                },
              ],
            };
          },
          write: (_, _, _) async => {},
          configureModel: (_) {
            modelSelections++;
            return selection.future;
          },
        ),
      );
      fixture.focus.requestFocus();
      await tester.pumpAndSettle();
      expect(find.text('gpt-5.4'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('chat-acp-config-button')));
      await tester.pumpAndSettle();
      expect(visibility, [true]);
      await tester.tap(find.byKey(const ValueKey('acp-config-model')));
      await tester.pumpAndSettle();
      expect(modelSelections, 1);
      await tester.tap(find.byKey(const ValueKey('chat-acp-config-button')));
      await tester.pumpAndSettle();
      expect(configLoads, 1);
      expect(find.byType(AcpConfigPanel), findsNothing);
      fixture.focus.unfocus();
      await tester.pumpAndSettle();
      expect(visibility, [true]);
      expect(tester.getSize(shell).height, 97);
      selection.complete();
      await tester.pumpAndSettle();
      expect(visibility, [true, false]);
      expect(tester.getSize(shell).height, 50);
    },
  );

  testWidgets(
    'external payload sends, running stops, and edit cancel stays available',
    (tester) async {
      final fixture = _ComposerFixture(tester);
      var sends = 0;
      var stops = 0;
      var exits = 0;
      await fixture.pump(hasExternalPayload: true, onSend: () => sends++);
      await tester.tap(send);
      expect(sends, 1);
      await fixture.pump(isProcessing: true, onCancel: () => stops++);
      await tester.tap(send);
      expect(stops, 1);
      fixture.controller.text = 'Edit draft';
      await fixture.pump(isEditing: true, onCancelEditing: () => exits++);
      await tester.tap(plus);
      expect(exits, 1);
      expect(fixture.controller.text, 'Edit draft');
      expect(find.byKey(const ValueKey('chat-input-add-files')), findsNothing);
    },
  );

  for (final dark in [false, true]) {
    testWidgets('narrow composer supports large text (dark=$dark)', (
      tester,
    ) async {
      final fixture = _ComposerFixture(tester);
      await fixture.pump(
        dark: dark,
        textScale: 2,
        width: 272,
        runtimeConfigButton: AcpConfigButton(
          modelLabel: 'provider/a-very-long-actual-model-name',
          isRunning: false,
          load: () async => {},
          write: (_, _, _) async => {},
        ),
      );
      fixture.focus.requestFocus();
      await tester.pumpAndSettle();
      fixture.controller.text = 'A long draft that wraps across several lines';
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(EditableText), findsOneWidget);
      expect(
        find.byKey(const ValueKey('chat-acp-config-button')),
        findsOneWidget,
      );
    });
  }
}

class _ComposerFixture {
  _ComposerFixture(this.tester) {
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
  }

  final WidgetTester tester;
  final controller = TextEditingController();
  final focus = FocusNode();
  final key = GlobalKey<ChatInputAreaState>();

  Future<void> pump({
    bool disableAnimations = false,
    bool dark = false,
    double textScale = 1,
    double width = 342,
    Future<void> Function()? onPickImages,
    Future<void> Function()? onPickAttachment,
    ValueChanged<AgentPermissionMode>? onPermission,
    Widget? runtimeConfigButton,
    String? selectedModelOverrideId,
    VoidCallback? onClearSelectedModelOverride,
    bool hasExternalPayload = false,
    bool isProcessing = false,
    bool isEditing = false,
    VoidCallback? onSend,
    VoidCallback? onCancel,
    VoidCallback? onCancelEditing,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 858),
            disableAnimations: disableAnimations,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: width,
                child: ChatInputArea(
                  key: key,
                  controller: controller,
                  focusNode: focus,
                  minimalComposer: true,
                  isProcessing: isProcessing,
                  hasExternalSendPayload: hasExternalPayload,
                  isEditingUserMessage: isEditing,
                  onCancelUserMessageEditing: onCancelEditing,
                  onSendMessage: onSend ?? () {},
                  onCancelTask: onCancel ?? () {},
                  onPickImages: onPickImages,
                  onPickAttachment: onPickAttachment,
                  agentPermissionMode: onPermission == null
                      ? null
                      : AgentPermissionMode.defaultMode,
                  agentPermissionModes: const [
                    AgentPermissionMode.readOnly,
                    AgentPermissionMode.defaultMode,
                    AgentPermissionMode.fullAccess,
                  ],
                  onAgentPermissionModeChanged: onPermission,
                  runtimeConfigButton: runtimeConfigButton,
                  selectedModelOverrideId: selectedModelOverrideId,
                  onClearSelectedModelOverride: onClearSelectedModelOverride,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}
