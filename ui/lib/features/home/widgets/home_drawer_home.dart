// ignore_for_file: invalid_use_of_protected_member

part of 'home_drawer.dart';

class _HomeConversationFilter {
  const _HomeConversationFilter({
    required this.id,
    this.agentId,
    this.name,
    this.mode = ConversationMode.agent,
  });

  static const all = _HomeConversationFilter(id: 'all');
  static const chat = _HomeConversationFilter(
    id: 'chat',
    mode: ConversationMode.chatOnly,
  );
  static const xiaowan = _HomeConversationFilter(
    id: 'xiaowan-acp',
    agentId: 'xiaowan-acp',
    name: '小万',
  );

  final String id;
  final String? agentId;
  final String? name;
  final ConversationMode mode;
}

extension _HomeDrawerHome on HomeDrawerState {
  Future<void> _loadHomeAgentCatalog() async {
    final request = ++_homeCatalogRequest;
    try {
      final catalog = await AgentRuntimeService.listAgents();
      if (!mounted || request != _homeCatalogRequest) return;
      setState(() {
        _homeAgentCatalog = catalog;
        final filters = _homeFilters;
        // Refresh the name as well as availability without resetting a valid
        // selection. An unavailable Agent falls back to the first usable one.
        _homeFilter =
            filters
                .where((filter) => filter.id == _homeFilter.id)
                .firstOrNull ??
            filters.firstWhere(
              (filter) => filter.agentId != null,
              orElse: () => _HomeConversationFilter.chat,
            );
      });
    } catch (error) {
      // Retain the last catalog during a transient native refresh failure.
      // Xiaowan remains available through the same built-in fallback as chat.
      debugPrint('Load home Agent catalog failed: $error');
    }
  }

  List<_HomeConversationFilter> get _homeFilters {
    final profiles = _homeAgentCatalog?.agents ?? const <AcpAgentProfile>[];
    final available = profiles
        .where(
          (profile) =>
              profile.enabled &&
              profile.installed == true &&
              profile.status.trim().toLowerCase() != 'missing',
        )
        .toList(growable: false);
    final ordered = [
      ...available.where((profile) => profile.id == 'xiaowan-acp'),
      ...available.where((profile) => profile.id == 'na-cloud'),
      ...available.where(
        (profile) => profile.id != 'xiaowan-acp' && profile.id != 'na-cloud',
      ),
    ];
    return [
      _HomeConversationFilter.all,
      if (!profiles.any((profile) => profile.id == 'xiaowan-acp'))
        _HomeConversationFilter.xiaowan,
      for (final profile in ordered)
        _HomeConversationFilter(
          id: profile.id,
          agentId: profile.id,
          name: profile.name.trim().isEmpty ? profile.id : profile.name.trim(),
        ),
      _HomeConversationFilter.chat,
    ];
  }

  bool _matchesHomeFilter(ConversationModel conversation) {
    if (!widget.homePage) return true;
    if (_homeFilter.id == 'all') return true;
    if (_homeFilter.mode == ConversationMode.chatOnly) {
      return conversation.mode == ConversationMode.chatOnly;
    }
    if (conversation.mode == ConversationMode.chatOnly ||
        conversation.mode == ConversationMode.openclaw) {
      return false;
    }
    // Old Xiaowan and scheduled child conversations predate agentId.
    final savedAgentId = conversation.agentId?.trim() ?? '';
    final agentId = savedAgentId.isEmpty ? 'xiaowan-acp' : savedAgentId;
    return AgentBrandIcon.normalizeAgentId(agentId) ==
        AgentBrandIcon.normalizeAgentId(_homeFilter.agentId ?? '');
  }

  Widget _buildHomePage() {
    final palette = context.omniPalette;
    return PopScope(
      canPop: !_homeSearchVisible && !_isSelectingConversations,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_isSelectingConversations) {
          _exitConversationSelection();
        } else if (_homeSearchVisible) {
          _closeHomeSearch();
        }
      },
      child: Scaffold(
        backgroundColor: palette.surfacePrimary,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isSelectingConversations)
                _buildConversationSelectionHeader(),
              if (!_homeSearchVisible) ...[
                if (!_isSelectingConversations)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _buildHomeAgentSwitcher(),
                          ),
                        ),
                        const SizedBox(width: 4),
                        OmniCircleButton(
                          key: const ValueKey('home-search-button'),
                          size: 40,
                          iconSize: 20,
                          tapTargetSize: MaterialTapTargetSize.padded,
                          icon: LucideIcons.search,
                          tooltip:
                              Localizations.localeOf(context).languageCode ==
                                  'en'
                              ? 'Search conversations'
                              : '搜索对话',
                          onPressed: _openHomeSearch,
                        ),
                        const SizedBox(width: 4),
                        Builder(
                          builder: (anchorContext) => OmniCircleButton(
                            key: const ValueKey('home-menu-button'),
                            size: 40,
                            iconSize: 20,
                            tapTargetSize: MaterialTapTargetSize.padded,
                            icon: LucideIcons.ellipsis,
                            tooltip: MaterialLocalizations.of(context)
                                .showMenuTooltip,
                            onPressed: () => _showHomeMenu(anchorContext),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              if (_homeSearchVisible)
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
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
                      OmniCircleButton(
                        key: const ValueKey('home-close-search'),
                        size: 40,
                        iconSize: 20,
                        tapTargetSize: MaterialTapTargetSize.padded,
                        icon: LucideIcons.x,
                        tooltip: MaterialLocalizations.of(context)
                            .closeButtonTooltip,
                        onPressed: _closeHomeSearch,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: isLoadingConversations
                      ? _buildConversationLoadingState()
                      : _isSearchActive
                      ? _buildSearchConversationBody(
                          _visibleConversationResults,
                        )
                      : _buildConversationTimelineBody(
                          _visibleConversationResults,
                        ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _isSelectingConversations
            ? _buildConversationSelectionBar()
            : null,
        floatingActionButton: _isSelectingConversations
            ? null
            : Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 24),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: FloatingActionButton(
                    key: const ValueKey('home-new-conversation'),
                    heroTag: 'home-new-conversation',
                    tooltip: context.l10n.homeDrawerNewChat,
                    onPressed: _openNewConversation,
                    backgroundColor: palette.accentPrimary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: const Icon(LucideIcons.plus, size: 26),
                  ),
                ),
              ),
      ),
    );
  }

  void _openHomeSearch() {
    if (_homeSearchVisible) return;
    setState(() => _homeSearchVisible = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _homeSearchVisible) _searchFocusNode.requestFocus();
    });
  }

  void _closeHomeSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() => _homeSearchVisible = false);
  }

  String _homeFilterLabel(_HomeConversationFilter filter) {
    final english = Localizations.localeOf(context).languageCode == 'en';
    return switch (filter.id) {
      'all' => english ? 'All conversations' : '全部对话',
      'chat' => english ? 'Chat' : '纯聊天',
      'xiaowan-acp' => english ? 'Xiaowan' : '小万',
      _ => filter.name ?? filter.id,
    };
  }

  Widget _buildHomeFilterIcon(_HomeConversationFilter filter, double size) {
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: filter.agentId != null
            ? AgentBrandIcon(agentId: filter.agentId!, size: size)
            : Icon(
                filter.id == 'all'
                    ? LucideIcons.layers
                    : LucideIcons.messageCircle,
                size: size,
                color: context.omniPalette.textPrimary,
              ),
      ),
    );
  }

  Widget _buildHomeAgentSwitcher({bool compact = false}) {
    final palette = context.omniPalette;
    final english = Localizations.localeOf(context).languageCode == 'en';
    // Keep the header's overflow glyph fully visible beside the overlay.
    final menuWidth = (MediaQuery.sizeOf(context).width - 84).clamp(0.0, 340.0);
    return Builder(
      builder: (anchorContext) => Tooltip(
        message: english ? 'Switch Agent' : '切换 Agent',
        child: InkWell(
          key: const ValueKey('home-agent-switcher'),
          borderRadius: BorderRadius.circular(14),
          onTap: _isBatchConversationActionRunning
              ? null
              : () async {
                  final anchor = glassPopupAnchorFromContext(anchorContext);
                  if (anchor == null) return;
                  performOmniSelectionHaptic();
                  final id = await showOmniMenu<String>(
                    context: anchorContext,
                    anchor: anchor,
                    width: menuWidth,
                    items: [
                      for (final filter in _homeFilters)
                        OmniPopupMenuItem<String>(
                          key: ValueKey('home-agent-option-${filter.id}'),
                          value: filter.id,
                          selected: _homeFilter.id == filter.id,
                          child: Row(
                            children: [
                              SizedBox.square(
                                dimension: 18,
                                child: _homeFilter.id == filter.id
                                    ? const Icon(LucideIcons.check, size: 18)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              ExcludeSemantics(
                                child: _buildHomeFilterIcon(
                                  filter,
                                  OmniMenuStyle.iconSize,
                                ),
                              ),
                              const SizedBox(width: OmniMenuStyle.iconGap),
                              Expanded(
                                child: Text(
                                  _homeFilterLabel(filter),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                  // The catalog can change while the menu is open. Select only
                  // a current entry using the existing conversation filter.
                  if (!mounted || _isBatchConversationActionRunning) return;
                  final filter = _homeFilters
                      .where((item) => item.id == id)
                      .firstOrNull;
                  if (filter != null) _selectHomeFilter(filter);
                },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: _buildHomeFilterIcon(_homeFilter, compact ? 24 : 30),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      _homeFilterLabel(_homeFilter),
                      key: const ValueKey('home-agent-name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 17 : 22,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    LucideIcons.chevronDown,
                    size: 18,
                    color: palette.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectHomeFilter(_HomeConversationFilter filter) {
    if (_homeFilter.id == filter.id) return;
    performOmniSelectionHaptic();
    setState(() => _homeFilter = filter);
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
    final english = Localizations.localeOf(context).languageCode == 'en';
    final actions = [
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
    final anchor = glassPopupAnchorFromContext(anchorContext);
    if (anchor == null) return;
    final selected = await showOmniMenu<int>(
      context: context,
      anchor: anchor,
      width: 260,
      items: [
        for (var i = 0; i < actions.length; i++)
          OmniPopupMenuItem<int>(
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
            padding: OmniMenuStyle.panelPadding,
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
