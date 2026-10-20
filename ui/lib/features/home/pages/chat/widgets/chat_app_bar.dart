part of 'chat_widgets.dart';

/// A presentation command. Its callback continues through the existing owner.
class ChatAppBarAction {
  const ChatAppBarAction({
    required this.label,
    required this.icon,
    required this.onSelected,
  });
  final String label;
  final IconData icon;
  final FutureOr<void> Function(BuildContext anchorContext) onSelected;
}

enum ChatSurfaceMode { workspace, normal, openclaw }

class ChatAcpAgentModeOption {
  const ChatAcpAgentModeOption({
    required this.id,
    required this.name,
    this.enabled = true,
    this.installed = true,
    this.status = 'online',
  });

  final String id;
  final String name;
  final bool enabled;
  final bool installed;
  final String status;

  bool get isAvailable =>
      enabled && installed && status.trim().toLowerCase() != 'missing';
}

/// 聊天页面 AppBar
class ChatAppBar extends StatelessWidget {
  final VoidCallback onMenuTap;
  final String? title;
  final List<ChatAppBarAction> actions;
  final Key? tutorialActionsAnchorKey;
  final VoidCallback? onPetTap;
  final bool isPetOpening;
  final bool isPetShowing;
  final VoidCallback? onOmniAiTap;
  final VoidCallback? onPureChatToggleTap;
  final VoidCallback? onAgentTap;
  final ValueChanged<String>? onAcpAgentTap;
  final VoidCallback? onPrimaryModeTap;
  final ChatSurfaceMode activeMode;
  final ValueChanged<ChatSurfaceMode> onModeChanged;
  final ChatIslandDisplayLayer displayLayer;
  final ValueChanged<ChatIslandDisplayLayer> onDisplayLayerChanged;
  final ValueChanged<BuildContext> onTerminalEnvironmentTap;
  final VoidCallback onTerminalTap;
  final VoidCallback onBrowserTap;
  final bool hasTerminalEnvironment;
  final bool isBrowserEnabled;
  final String? activeToolType;
  final bool isAgentReady;
  final bool isAgentConnected;
  final bool isAgentLoading;
  final bool isAgentSelected;
  final bool isOmniAiSelected;
  final List<ChatAcpAgentModeOption> acpAgentModes;
  final String? activeAcpAgentId;
  final bool showAppUpdateIndicator;
  final VoidCallback? onAppUpdateTap;
  final String? appUpdateTooltip;
  final bool translucent;
  final AppBackgroundVisualProfile visualProfile;
  final bool showMenuButton;
  final bool showSurfaceSwitcher;
  final bool showPureChatToggle;
  final bool isPureChatSelected;
  final bool isPureChatToggleLocked;
  final bool showWorkspacePaneButton;
  final VoidCallback? onWorkspacePaneTap;
  final Key? tutorialMenuAnchorKey;
  final Key? tutorialPetAnchorKey;
  final Key? tutorialIslandAnchorKey;
  final Key? tutorialModeAnchorKey;

  const ChatAppBar({
    super.key,
    required this.onMenuTap,
    this.title,
    this.actions = const [],
    this.tutorialActionsAnchorKey,
    this.onPetTap,
    this.isPetOpening = false,
    this.isPetShowing = false,
    this.onOmniAiTap,
    this.onPureChatToggleTap,
    this.onAgentTap,
    this.onAcpAgentTap,
    this.onPrimaryModeTap,
    required this.activeMode,
    required this.onModeChanged,
    this.displayLayer = ChatIslandDisplayLayer.mode,
    required this.onDisplayLayerChanged,
    required this.onTerminalEnvironmentTap,
    required this.onTerminalTap,
    required this.onBrowserTap,
    this.hasTerminalEnvironment = false,
    this.isBrowserEnabled = false,
    this.activeToolType,
    this.isAgentReady = false,
    this.isAgentConnected = false,
    this.isAgentLoading = false,
    this.isAgentSelected = false,
    this.isOmniAiSelected = true,
    this.acpAgentModes = const <ChatAcpAgentModeOption>[],
    this.activeAcpAgentId,
    this.showAppUpdateIndicator = false,
    this.onAppUpdateTap,
    this.appUpdateTooltip,
    this.translucent = false,
    this.visualProfile = AppBackgroundVisualProfile.defaultProfile,
    this.showMenuButton = true,
    this.showSurfaceSwitcher = true,
    this.showPureChatToggle = false,
    this.isPureChatSelected = false,
    this.isPureChatToggleLocked = true,
    this.showWorkspacePaneButton = false,
    this.onWorkspacePaneTap,
    this.tutorialMenuAnchorKey,
    this.tutorialPetAnchorKey,
    this.tutorialIslandAnchorKey,
    this.tutorialModeAnchorKey,
  });

  String _modeLabel(bool english) {
    if (isPureChatSelected) return english ? 'Pure chat' : '纯聊天';
    for (final agent in acpAgentModes) {
      if (agent.id == activeAcpAgentId) return agent.name;
    }
    return english ? 'OmniBot Agent' : '小万 Agent';
  }

  RelativeRect _menuPosition(BuildContext anchorContext) {
    final button = anchorContext.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(anchorContext).overlay!.context.findRenderObject()!
            as RenderBox;
    return RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(
          Offset(0, button.size.height + 8),
          ancestor: overlay,
        ),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );
  }

  Future<void> _openModeMenu(BuildContext anchorContext) async {
    final english = Localizations.localeOf(anchorContext).languageCode == 'en';
    final available = acpAgentModes
        .where((agent) => agent.isAvailable)
        .toList();
    if (!available.any((agent) => agent.id == 'xiaowan-acp')) {
      available.insert(
        0,
        ChatAcpAgentModeOption(
          id: 'xiaowan-acp',
          name: english ? 'OmniBot Agent' : '小万 Agent',
        ),
      );
    }
    final selected = await showMenu<String>(
      context: anchorContext,
      position: _menuPosition(anchorContext),
      color: anchorContext.omniPalette.surfacePrimary,
      elevation: 8,
      shadowColor: anchorContext.omniPalette.shadowColor.withValues(
        alpha: 0.12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
      requestFocus: false,
      items: [
        for (final agent in available)
          PopupMenuItem<String>(
            key: ValueKey(
              'chat-app-bar-mode-menu-${agent.id == 'xiaowan-acp' ? 'xiaowan-acp' : 'acp-${agent.id}'}',
            ),
            value: agent.id,
            child: Row(
              children: [
                AgentBrandIcon(
                  agentId: agent.id,
                  size: 20,
                  tint: anchorContext.omniPalette.textPrimary,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(agent.name)),
                if (!isPureChatSelected &&
                    (agent.id == activeAcpAgentId ||
                        (agent.id == 'xiaowan-acp' &&
                            (activeAcpAgentId?.isEmpty ?? true))))
                  const Icon(LucideIcons.check, size: 18),
              ],
            ),
          ),
        if (isAgentSelected ||
            (!isPureChatToggleLocked && onPureChatToggleTap != null))
          PopupMenuItem<String>(
            key: const ValueKey('chat-app-bar-mode-menu-pure-chat'),
            value: 'pure-chat',
            child: Row(
              children: [
                const Icon(LucideIcons.messageCircle, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(english ? 'Pure chat' : '纯聊天')),
                if (isPureChatSelected) const Icon(LucideIcons.check, size: 18),
              ],
            ),
          ),
      ],
    );
    if (!anchorContext.mounted || selected == null) return;
    if (selected == 'pure-chat') {
      onPureChatToggleTap?.call();
    } else if (onAcpAgentTap != null) {
      onAcpAgentTap!(selected);
    } else if (selected == 'xiaowan-acp') {
      onOmniAiTap?.call();
    } else {
      onAgentTap?.call();
    }
  }

  Future<void> _openActionsMenu(BuildContext anchorContext) async {
    final english = Localizations.localeOf(anchorContext).languageCode == 'en';
    final items = <ChatAppBarAction>[
      ...actions,
      ChatAppBarAction(
        label: activeMode == ChatSurfaceMode.workspace
            ? (english ? 'Return to conversation' : '返回对话')
            : (english ? 'Workspace files' : '工作区文件'),
        icon: LucideIcons.folder,
        onSelected: (_) {
          if (!showSurfaceSwitcher && onWorkspacePaneTap != null) {
            onWorkspacePaneTap!();
          } else {
            onModeChanged(
              activeMode == ChatSurfaceMode.workspace
                  ? ChatSurfaceMode.normal
                  : ChatSurfaceMode.workspace,
            );
          }
        },
      ),
      ChatAppBarAction(
        label: english ? 'Terminal' : '终端',
        icon: LucideIcons.terminal,
        onSelected: (_) => onTerminalTap(),
      ),
      ChatAppBarAction(
        label: english ? 'Environment variables' : '环境变量',
        icon: LucideIcons.slidersHorizontal,
        onSelected: onTerminalEnvironmentTap,
      ),
      if (isBrowserEnabled)
        ChatAppBarAction(
          label: english ? 'Browser' : '浏览器',
          icon: LucideIcons.globe,
          onSelected: (_) => onBrowserTap(),
        ),
      if (onPrimaryModeTap != null)
        ChatAppBarAction(
          label: english ? 'Agent sessions' : 'Agent 会话',
          icon: LucideIcons.messagesSquare,
          onSelected: (_) => onPrimaryModeTap!(),
        ),
      if (onPetTap != null)
        ChatAppBarAction(
          label: isPetShowing
              ? (english ? 'Hide pet' : '收起宠物')
              : (english ? 'Show pet' : '唤起宠物'),
          icon: LucideIcons.pawPrint,
          onSelected: (_) {
            if (!isPetOpening) onPetTap!();
          },
        ),
      if (showAppUpdateIndicator && onAppUpdateTap != null)
        ChatAppBarAction(
          label: appUpdateTooltip ?? (english ? 'Check for updates' : '检查更新'),
          icon: LucideIcons.download,
          onSelected: (_) => onAppUpdateTap!(),
        ),
    ];
    final selected = await showMenu<int>(
      context: anchorContext,
      position: _menuPosition(anchorContext),
      color: anchorContext.omniPalette.surfacePrimary,
      elevation: 8,
      shadowColor: anchorContext.omniPalette.shadowColor.withValues(
        alpha: 0.12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
      requestFocus: false,
      items: [
        for (var index = 0; index < items.length; index++)
          PopupMenuItem<int>(
            value: index,
            child: Row(
              children: [
                Icon(items[index].icon, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(items[index].label)),
              ],
            ),
          ),
      ],
    );
    if (selected != null && anchorContext.mounted) {
      await items[selected].onSelected(anchorContext);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    final english = Localizations.localeOf(context).languageCode == 'en';
    final foreground = translucent
        ? visualProfile.appBarIconColor
        : palette.textPrimary;
    final secondary = translucent
        ? visualProfile.secondaryTextColor
        : palette.textSecondary;
    return TextFieldTapRegion(
      child: ColoredBox(
        key: const ValueKey('chat-app-bar-background'),
        color: translucent ? Colors.transparent : palette.pageBackground,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              if (showMenuButton) ...[
                KeyedSubtree(
                  key: tutorialMenuAnchorKey,
                  child: OmniCircleButton(
                    key: const ValueKey('chat-app-bar-menu-button'),
                    icon: LucideIcons.chevronLeft,
                    tooltip: english ? 'Back to conversations' : '返回会话列表',
                    foregroundColor: palette.textPrimary,
                    onPressed: onMenuTap,
                  ),
                ),
                const SizedBox(width: 18),
              ],
              Expanded(
                child: KeyedSubtree(
                  key: tutorialModeAnchorKey,
                  child: Tooltip(
                    message: english ? 'Switch chat mode' : '切换聊天模式',
                    child: Builder(
                      builder: (anchorContext) => InkWell(
                        key: const ValueKey('chat-app-bar-pure-chat-button'),
                        onTap: () => _openModeMenu(anchorContext),
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                activeMode == ChatSurfaceMode.workspace
                                    ? (english ? 'Workspace' : '工作区')
                                    : ((title?.trim().isNotEmpty ?? false)
                                          ? title!
                                          : (english
                                                ? 'New conversation'
                                                : '新对话')),
                                key: const ValueKey('chat-app-bar-title'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 18,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                  color: foreground,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPureChatSelected
                                        ? LucideIcons.messageCircle
                                        : LucideIcons.bot,
                                    size: 15,
                                    color: secondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _modeLabel(english),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 1.2,
                                        color: secondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    LucideIcons.chevronDown,
                                    size: 14,
                                    color: secondary,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              KeyedSubtree(
                key: tutorialActionsAnchorKey,
                child: KeyedSubtree(
                  key: tutorialPetAnchorKey,
                  child: KeyedSubtree(
                    key: tutorialIslandAnchorKey,
                    child: Builder(
                      builder: (anchorContext) => OmniCircleButton(
                        key: const ValueKey('chat-app-bar-more-button'),
                        icon: LucideIcons.ellipsis,
                        tooltip: english ? 'Conversation options' : '对话选项',
                        foregroundColor: palette.textPrimary,
                        onPressed: () => _openActionsMenu(anchorContext),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
