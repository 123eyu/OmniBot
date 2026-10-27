import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ui/theme/omni_theme_palette.dart';

import 'navigation_dock.dart';

@Preview(name: 'FlClash navigation · light', size: Size(390, 240))
Widget flClashNavigationLightPreview() => const _DockPreview();

@Preview(name: 'FlClash navigation · dark', size: Size(390, 240))
Widget flClashNavigationDarkPreview() => const _DockPreview(dark: true);

class _DockPreview extends StatefulWidget {
  const _DockPreview({this.dark = false});

  final bool dark;

  @override
  State<_DockPreview> createState() => _DockPreviewState();
}

class _DockPreviewState extends State<_DockPreview> {
  int _selectedIndex = 0;

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
        body: Stack(
          children: [
            Center(child: Text(['首页', 'Agents', '轨迹', '设置'][_selectedIndex])),
            Align(
              alignment: Alignment.bottomCenter,
              child: FlClashNavigationDock(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (value) =>
                    setState(() => _selectedIndex = value),
                destinations: const [
                  FlClashNavigationDestination(
                    icon: LucideIcons.house,
                    label: '首页',
                  ),
                  FlClashNavigationDestination(
                    icon: LucideIcons.bot,
                    label: 'Agents',
                  ),
                  FlClashNavigationDestination(
                    icon: LucideIcons.route,
                    label: '轨迹',
                  ),
                  FlClashNavigationDestination(
                    icon: LucideIcons.settings,
                    label: '设置',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
