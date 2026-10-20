// ignore_for_file: invalid_use_of_protected_member

part of 'home_drawer.dart';

enum _HomeConversationFilter { all, agent, chat }

extension _HomeDrawerHome on HomeDrawerState {
  bool _matchesHomeFilter(ConversationModel conversation) {
    if (!widget.homePage) return true;
    return switch (_homeFilter) {
      _HomeConversationFilter.all => true,
      _HomeConversationFilter.agent =>
        conversation.mode != ConversationMode.chatOnly,
      _HomeConversationFilter.chat =>
        conversation.mode == ConversationMode.chatOnly,
    };
  }

  Widget _buildHomePage() {
    final palette = context.omniPalette;
    final searchKeyboardVisible =
        _homeSearchVisible && MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: palette.surfacePrimary,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (searchKeyboardVisible)
              const SizedBox(height: 12)
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/login/logo-66664x.png',
                      width: 38,
                      height: 38,
                      semanticLabel: 'OmniBot',
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'OmniBot',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.7,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                    Builder(
                      builder: (anchorContext) => OmniCircleButton(
                        key: const ValueKey('home-menu-button'),
                        icon: LucideIcons.ellipsis,
                        tooltip: MaterialLocalizations.of(context)
                            .showMenuTooltip,
                        onPressed: () => _showHomeMenu(anchorContext),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final filter in _HomeConversationFilter.values) ...[
                      if (filter != _HomeConversationFilter.all)
                        const SizedBox(width: 8),
                      _buildHomeFilter(filter),
                    ],
                  ],
                ),
              ),
            ),
            if (_homeSearchVisible)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: HomeDrawerSearchField(
                        key: widget.searchFieldKey,
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        isSearching: _isSearching,
                        textColor: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      key: const ValueKey('home-close-search'),
                      tooltip: MaterialLocalizations.of(context)
                          .closeButtonTooltip,
                      onPressed: () {
                        _searchController.clear();
                        _searchFocusNode.unfocus();
                        setState(() => _homeSearchVisible = false);
                      },
                      icon: const Icon(LucideIcons.x, size: 20),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: isLoadingConversations
                    ? _buildConversationLoadingState()
                    : _isSearchActive
                    ? _buildSearchConversationBody(_visibleConversationResults)
                    : _buildConversationTimelineBody(
                        _visibleConversationResults,
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 6, bottom: 24),
        child: SizedBox(
          width: 64,
          height: 64,
          child: FloatingActionButton(
            key: const ValueKey('home-new-conversation'),
            heroTag: 'home-new-conversation',
            tooltip: context.l10n.homeDrawerNewChat,
            onPressed: _openNewConversation,
            backgroundColor: palette.accentPrimary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            shape: const CircleBorder(),
            elevation: 3,
            child: const Icon(LucideIcons.plus, size: 32),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeFilter(_HomeConversationFilter filter) {
    final palette = context.omniPalette;
    final english = Localizations.localeOf(context).languageCode == 'en';
    final selected = _homeFilter == filter;
    final label = switch (filter) {
      _HomeConversationFilter.all => english ? 'All' : '全部',
      _HomeConversationFilter.agent => 'Agent',
      _HomeConversationFilter.chat => english ? 'Chat' : '聊天',
    };
    final foreground = selected
        ? Theme.of(context).colorScheme.onPrimary
        : palette.textPrimary;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? palette.accentPrimary : palette.surfaceSecondary,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          key: ValueKey('home-filter-${filter.name}'),
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            performOmniSelectionHaptic();
            setState(() => _homeFilter = filter);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (filter != _HomeConversationFilter.all) ...[
                  Icon(
                    filter == _HomeConversationFilter.agent
                        ? LucideIcons.bot
                        : LucideIcons.messageCircle,
                    size: 18,
                    color: foreground,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.2,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showHomeMenu(BuildContext anchorContext) async {
    if (_homeMenuOpening) return;
    _homeMenuOpening = true;
    try {
      await _openHomeMenu(anchorContext);
    } finally {
      _homeMenuOpening = false;
    }
  }

  Future<void> _openHomeMenu(BuildContext anchorContext) async {
    // Home remains mounted under settings/plugin pages. Read the existing
    // plugin registry again so newly enabled or removed actions are reflected.
    await _loadWebQuickActions();
    if (!mounted || !anchorContext.mounted) return;
    final palette = context.omniPalette;
    final english = Localizations.localeOf(context).languageCode == 'en';
    final actions = [
      _DrawerShortcutAction(
        label: english ? 'Search conversations' : '搜索对话',
        icon: LucideIcons.search,
        onTap: () {
          setState(() => _homeSearchVisible = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _searchFocusNode.requestFocus();
          });
        },
      ),
      _DrawerShortcutAction(
        label: context.l10n.homeDrawerArchive,
        assetPath: 'assets/home/archive_icon.svg',
        onTap: () => _navigateTo('/home/archived_conversations'),
      ),
      ..._shortcutActions,
      if (_webQuickActions.isNotEmpty)
        _DrawerShortcutAction(
          label: english ? 'Web interfaces' : 'Web 界面',
          icon: LucideIcons.globe,
          onTap: _showHomeWebActions,
        ),
    ];
    final box = anchorContext.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    final selected = await showMenu<int>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(
          origin.dx,
          origin.dy + box.size.height + 8,
          box.size.width,
          0,
        ),
        Offset.zero & overlay.size,
      ),
      color: palette.surfacePrimary,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      constraints: const BoxConstraints(minWidth: 224, maxWidth: 300),
      items: [
        for (var i = 0; i < actions.length; i++)
          PopupMenuItem<int>(
            key: ValueKey('home-menu-item-$i'),
            value: i,
            child: Row(
              children: [
                _shortcutIcon(actions[i], size: 20),
                const SizedBox(width: 14),
                Expanded(child: Text(actions[i].label)),
              ],
            ),
          ),
      ],
    );
    if (!mounted || selected == null) return;
    actions[selected].onTap();
  }

  Future<void> _showHomeWebActions() async {
    await _refreshWebQuickActionStatuses();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              for (final action in _webQuickActions)
                _buildWebPopoverOptionTile(
                  sheetContext,
                  action,
                  surface: sheetContext.omniPalette.surfacePrimary,
                  english: Localizations.localeOf(context).languageCode == 'en',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
