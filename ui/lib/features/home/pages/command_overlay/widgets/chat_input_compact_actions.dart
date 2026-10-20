part of 'chat_input_area.dart';

enum _CompactComposerAction { images, files, permissions }

extension _CompactComposerActions on _ChatInputAreaStateBase {
  Widget _buildCompactAddButton() {
    final english = Localizations.localeOf(context).languageCode == 'en';
    final canOpen =
        widget.onPickImages != null ||
        widget.onPickAttachment != null ||
        _shouldShowAgentPermissionSelector;
    return Builder(
      builder: (anchor) => IconButton(
        key: const ValueKey('chat-input-add-or-cancel-edit-button'),
        padding: EdgeInsets.zero,
        tooltip: widget.isEditingUserMessage
            ? (english ? 'Exit editing' : '退出编辑')
            : (english ? 'Attachments and permissions' : '附件与权限'),
        icon: AnimatedRotation(
          key: const ValueKey('chat-input-add-or-cancel-edit-icon'),
          turns: widget.isEditingUserMessage ? 0.125 : 0,
          duration: _compactAnimationDuration,
          curve: Curves.easeOutCubic,
          child: Icon(
            LucideIcons.plus,
            size: 22,
            color: context.omniPalette.textPrimary,
          ),
        ),
        onPressed: widget.isEditingUserMessage
            ? widget.onCancelUserMessageEditing
            : canOpen
            ? () => _openCompactActions(anchor)
            : null,
      ),
    );
  }

  Future<void> _openCompactActions(BuildContext anchorContext) async {
    if (_compactActionsMenu != null ||
        !_composerStateMachine.beginPopupOpening(
          ChatComposerPopup.compactActions,
        )) {
      return;
    }
    final anchor = glassPopupAnchorFromContext(anchorContext);
    if (anchor == null) {
      _composerStateMachine.popupClosed(ChatComposerPopup.compactActions);
      return;
    }
    final palette = context.omniPalette;
    final english = Localizations.localeOf(context).languageCode == 'en';
    final handle = showOverlayGlassPopup<_CompactComposerAction>(
      context: context,
      anchor: anchor,
      preferBelow: false,
      transitionDuration: _compactAnimationDuration,
      reverseTransitionDuration: Duration.zero,
      builder: (handle) => TextFieldTapRegion(
        child: Material(
          color: palette.surfacePrimary,
          elevation: 8,
          shadowColor: palette.shadowColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 224,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.onPickImages != null)
                    _CompactComposerMenuRow(
                      action: _CompactComposerAction.images,
                      icon: LucideIcons.image,
                      title: english ? 'Photos' : '图片',
                      onTap: () =>
                          handle.dismiss(_CompactComposerAction.images),
                    ),
                  if (widget.onPickAttachment != null)
                    _CompactComposerMenuRow(
                      action: _CompactComposerAction.files,
                      icon: LucideIcons.paperclip,
                      title: english ? 'Files' : '文件',
                      onTap: () => handle.dismiss(_CompactComposerAction.files),
                    ),
                  if (_shouldShowAgentPermissionSelector)
                    _CompactComposerMenuRow(
                      action: _CompactComposerAction.permissions,
                      icon: LucideIcons.shield,
                      title: english ? 'Permissions' : '权限模式',
                      subtitle: _agentPermissionLabel(
                        widget.agentPermissionMode!,
                      ),
                      onTap: () =>
                          handle.dismiss(_CompactComposerAction.permissions),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    _compactActionsMenu = handle;
    _composerStateMachine.popupOpened(ChatComposerPopup.compactActions);
    try {
      final action = await handle.future;
      if (!mounted || !anchorContext.mounted) return;
      // Hold the layout through the native picker or the existing permission
      // popup. A handoff must not briefly collapse the focused text editor.
      switch (action) {
        case _CompactComposerAction.images:
          await widget.onPickImages?.call();
        case _CompactComposerAction.files:
          await widget.onPickAttachment?.call();
        case _CompactComposerAction.permissions:
          await _openAgentPermissionMenu(anchorContext, preferBelow: false);
        case null:
          break;
      }
    } finally {
      if (_compactActionsMenu == handle) {
        _compactActionsMenu = null;
        if (mounted) {
          _composerStateMachine.popupClosed(ChatComposerPopup.compactActions);
        }
      }
    }
  }
}

class _CompactComposerMenuRow extends StatelessWidget {
  const _CompactComposerMenuRow({
    required this.action,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final _CompactComposerAction action;
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    return InkWell(
      key: ValueKey('chat-input-add-${action.name}'),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            children: [
              Icon(icon, size: 20, color: palette.textPrimary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        color: palette.textPrimary,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (action == _CompactComposerAction.permissions)
                Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: palette.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
