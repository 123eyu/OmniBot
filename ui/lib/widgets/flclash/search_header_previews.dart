import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ui/theme/omni_theme_palette.dart';

import 'search_header.dart';

@Preview(name: 'FlClash proxy search · light', size: Size(390, 220))
Widget flClashSearchLightPreview() => const _SearchPreview();

@Preview(name: 'FlClash proxy search · dark', size: Size(390, 220))
Widget flClashSearchDarkPreview() => const _SearchPreview(dark: true);

class _SearchPreview extends StatefulWidget {
  const _SearchPreview({this.dark = false});
  final bool dark;
  @override
  State<_SearchPreview> createState() => _SearchPreviewState();
}

class _SearchPreviewState extends State<_SearchPreview> {
  bool _searching = false;
  final _controller = TextEditingController();
  final _focus = FocusNode();
  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.dark
        ? OmniThemePalette.dark
        : OmniThemePalette.light;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: widget.dark ? Brightness.dark : Brightness.light,
        colorSchemeSeed: palette.accentPrimary,
        extensions: [palette],
      ),
      home: Scaffold(
        backgroundColor: palette.pageBackground,
        appBar: FlClashSearchHeader(
          title: const Text('Agents'),
          searching: _searching,
          controller: _controller,
          focusNode: _focus,
          onSearch: () => setState(() => _searching = true),
          onClose: () {
            _controller.clear();
            _focus.unfocus();
            setState(() => _searching = false);
          },
          actions: [
            IconButton(onPressed: () {}, icon: const Icon(LucideIcons.plus)),
            IconButton(
              onPressed: () {},
              icon: const Icon(LucideIcons.ellipsis),
            ),
          ],
          searchActions: [
            IconButton(onPressed: () {}, icon: const Icon(LucideIcons.plus)),
          ],
        ),
        body: const Center(child: Text('点击搜索，查看 FlClash 的展开与收起动画')),
      ),
    );
  }
}
