import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ui/features/home/widgets/home_drawer_search_field.dart';
import 'package:ui/services/tool_catalog_service.dart';
import 'package:ui/theme/theme_context.dart';
import 'package:ui/utils/ui.dart';
import 'package:ui/widgets/common_app_bar.dart';
import 'package:ui/widgets/settings_detail_sheet.dart';
import 'package:ui/widgets/settings_ui.dart';

class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key});

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> with WidgetsBindingObserver {
  final _search = TextEditingController();
  final _focus = FocusNode();
  List<CatalogTool> _local = [];
  List<CatalogServer> _servers = [];
  bool _localLoading = true;
  bool _remoteLoading = true;
  bool _localFailed = false;
  bool _remoteFailed = false;

  String _text(String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : zh;
  String get _query => _search.text.trim().toLowerCase();
  bool get _loading => _localLoading || _remoteLoading;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _search.addListener(_searchChanged);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_loading) _load();
  }

  void _searchChanged() => setState(() {});

  Future<void> _load() async {
    setState(() {
      _localLoading = _remoteLoading = true;
      _localFailed = _remoteFailed = false;
    });
    await Future.wait([_loadLocal(), _loadRemote()]);
  }

  Future<void> _loadLocal() async {
    try {
      final tools = await ToolCatalogService.localTools();
      if (mounted) setState(() => _local = tools);
    } catch (_) {
      if (mounted) {
        setState(() {
          _local = [];
          _localFailed = true;
        });
      }
    } finally {
      if (mounted) setState(() => _localLoading = false);
    }
  }

  Future<void> _loadRemote() async {
    try {
      final servers = await ToolCatalogService.remoteTools();
      if (mounted) setState(() => _servers = servers);
    } catch (_) {
      if (mounted) {
        setState(() {
          _servers = [];
          _remoteFailed = true;
        });
      }
    } finally {
      if (mounted) setState(() => _remoteLoading = false);
    }
  }

  Future<void> _configure(String path) async {
    await context.push(path);
    if (mounted && !_loading) await _load();
  }

  String _groupName(String group) => switch (group) {
    'plugin' => _text('插件工具', 'Plugin tools'),
    'mcp' => _text('远程 MCP', 'Remote MCP'),
    _ => _text('内置工具', 'Built-in tools'),
  };

  String _status(String status) => switch (status) {
    'discovered' => _text('已发现', 'Discovered'),
    'disabled' => _text('未启用', 'Disabled'),
    'unavailable' => _text('连接失败', 'Connection failed'),
    _ => _text('已注册', 'Registered'),
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    final all = [..._local, ..._servers.expand((s) => s.tools)];
    final visible = all.where((tool) => tool.matches(_query)).toList();
    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: CommonAppBar(
        title: _text('工具', 'Tools'),
        primary: true,
        actions: [
          IconButton(
            tooltip: _text('刷新工具', 'Refresh tools'),
            onPressed: _loading ? null : _load,
            icon: const Icon(LucideIcons.refreshCw, size: 20),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: HomeDrawerSearchField(
                controller: _search,
                focusNode: _focus,
                isSearching: false,
                textColor: palette.textPrimary,
                hintText: _text('搜索名称、用途或来源', 'Search name, purpose or source'),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  if (!_loading) await _load();
                },
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: edgeToEdgeScrollPadding(
                    context,
                    const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        _text(
                          '查看内置 Agent 与已配置扩展的工具目录。实际调用取决于 Agent、会话配置、权限及运行环境。',
                          'Explore the built-in agent and configured extensions. Actual access depends on the agent, session, permissions and runtime.',
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.55,
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                    if (_localLoading || _remoteLoading)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _localLoading
                                  ? _text('读取工具目录…', 'Loading tools…')
                                  : _text(
                                      '发现远程工具…',
                                      'Discovering remote tools…',
                                    ),
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_localFailed)
                      _error(_text('本地工具加载失败', 'Could not load local tools')),
                    if (_remoteFailed)
                      _error(_text('远程工具加载失败', 'Could not load remote tools')),
                    if (_query.isNotEmpty && visible.isEmpty && !_loading)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          _text(
                            '没有找到匹配的工具，试试其他关键词。',
                            'No matching tools. Try another keyword.',
                          ),
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    for (final group in ['builtin', 'plugin', 'mcp'])
                      if (_query.isEmpty ||
                          visible.any((t) => t.group == group)) ...[
                        _heading(
                          group,
                          visible.where((t) => t.group == group).length,
                        ),
                        _buildGroupSection(
                          group,
                          visible.where((t) => t.group == group).toList(),
                        ),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupSection(String group, List<CatalogTool> groupTools) {
    final rows = <Widget>[
      for (final tool in groupTools) _toolRow(tool),
      if (group == 'plugin' &&
          !_localLoading &&
          !_localFailed &&
          !_local.any((t) => t.group == group))
        _note(
          _text(
            '启用插件后，其工具会显示在这里。',
            'Enable a plugin to see its tools here.',
          ),
        ),
      if (group == 'mcp' && !_remoteLoading && !_remoteFailed) ...[
        for (final server in _servers.where((s) => s.tools.isEmpty))
          _note(
            '${server.name} · ${server.status == 'discovered' ? _text('未提供工具', 'No tools exposed') : _status(server.status)}',
          ),
        if (_servers.isEmpty)
          _note(
            _text(
              '尚未配置远程 MCP 服务。',
              'No remote MCP servers configured.',
            ),
          ),
      ],
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return OmniSettingsGroup(dividerIndent: 46, children: rows);
  }

  Widget _heading(String group, int count) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '${_groupName(group)} · $count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: context.omniPalette.textTertiary,
            ),
          ),
        ),
        if (group != 'builtin')
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 28),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _configure(
              group == 'plugin' ? '/home/plugin_market' : '/home/mcp_tools',
            ),
            child: Text(
              _text('管理', 'Manage'),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
          ),
      ],
    ),
  );

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          height: 1.5,
          color: context.omniPalette.textSecondary,
        ),
      ),
    ),
  );

  Widget _error(String text) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: OmniSettingsCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                color: context.omniPalette.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: _loading ? null : _load,
            child: Text(_text('重试', 'Retry')),
          ),
        ],
      ),
    ),
  );

  Widget _toolRow(CatalogTool tool) {
    final palette = context.omniPalette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showDetail(tool),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  switch (tool.group) {
                    'plugin' => LucideIcons.puzzle,
                    'mcp' => LucideIcons.globe,
                    _ => LucideIcons.wrench,
                  },
                  size: 18,
                  color: palette.textPrimary.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tool.displayName,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: palette.textPrimary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tool.description.isEmpty ? tool.name : tool.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        if (tool.source.isNotEmpty) tool.source,
                        _status(tool.status),
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: palette.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDetail(CatalogTool tool) async {
    final path = await showSettingsDetailSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SettingsDetailSheet(
        title: tool.displayName,
        subtitle:
            '${_groupName(tool.group)} · ${tool.source.isEmpty ? _text('内置 Agent', 'Built-in agent') : tool.source} · ${_status(tool.status)}',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              tool.name,
              style: TextStyle(
                fontSize: 12,
                color: context.omniPalette.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            SelectableText(
              tool.description.isEmpty
                  ? _text('暂无工具说明', 'No description provided')
                  : tool.description,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: context.omniPalette.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _text('使用条件', 'Requirements'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              _text(
                '工具由 Agent 在对话中调用。已注册或已发现表示目录中存在此工具，不代表权限、模型或运行环境已就绪；具体要求见工具说明。远程结果可能来自最近的发现缓存。',
                'Tools are invoked by agents in a conversation. Registered or discovered tools may still require permissions, a model or runtime setup; see the description for requirements. Remote results may use the recent discovery cache.',
              ),
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: context.omniPalette.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              sheetContext,
              tool.group == 'plugin'
                  ? '/home/plugin_market'
                  : tool.group == 'mcp'
                  ? '/home/mcp_tools'
                  : '/home/authorize_setting',
            ),
            child: Text(
              tool.group == 'builtin'
                  ? _text('权限设置', 'Permissions')
                  : _text('管理来源', 'Manage source'),
            ),
          ),
        ],
      ),
    );
    if (mounted && path != null) await _configure(path);
  }
}
