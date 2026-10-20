import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:ui/theme/theme_context.dart';

/// Menu metrics shared with the home conversation context menu.
/// Keep the reference menu unchanged; other menus consume these same metrics.
abstract final class OmniMenuStyle {
  static const rowRadius = BorderRadius.all(Radius.circular(18));
  static const panelRadius = BorderRadius.all(Radius.circular(20));
  static const contentPadding = EdgeInsets.all(12);
  static const panelPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 10,
  );
  static const minHeight = 48.0;
  static const iconSize = 20.0;
  static const iconGap = 14.0;
  static const labelStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.25,
  );
}

/// A rounded menu row, independent of route, selection, and dismissal ownership.
/// Use [child] for rich rows, or label/leading/trailing for ordinary actions.
class OmniMenuItem extends StatelessWidget {
  const OmniMenuItem({
    super.key,
    required this.onTap,
    this.child,
    this.label,
    this.leading,
    this.trailing,
    this.subtitle,
    this.selected = false,
    this.enabled = true,
    this.destructive = false,
  }) : assert(child != null || label != null);

  final VoidCallback? onTap;
  final Widget? child;
  final String? label;
  final Widget? leading;
  final Widget? trailing;
  final String? subtitle;
  final bool selected;
  final bool enabled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    final color = !enabled
        ? palette.textTertiary
        : destructive
        ? Theme.of(context).colorScheme.error
        : palette.textPrimary;
    return Semantics(
      selected: selected,
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: OmniMenuStyle.rowRadius,
          splashColor: color.withValues(alpha: 0.08),
          highlightColor: color.withValues(alpha: 0.04),
          hoverColor: color.withValues(alpha: 0.04),
          focusColor: color.withValues(alpha: 0.04),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: OmniMenuStyle.minHeight,
            ),
            child: Padding(
              padding: OmniMenuStyle.contentPadding,
              child: IconTheme.merge(
                data: IconThemeData(color: color, size: OmniMenuStyle.iconSize),
                child: DefaultTextStyle.merge(
                  style: OmniMenuStyle.labelStyle.copyWith(color: color),
                  child:
                      child ??
                      Row(
                        children: [
                          if (leading != null) ...[
                            leading!,
                            const SizedBox(width: OmniMenuStyle.iconGap),
                          ],
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.3,
                                      color: palette.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (trailing != null) ...[
                            const SizedBox(width: 12),
                            trailing!,
                          ],
                        ],
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Native popup-menu entry with an individually rounded interaction surface.
/// Retains PopupMenuItem's keyboard navigation and pop-before-callback behavior.
class OmniPopupMenuItem<T> extends PopupMenuItem<T> {
  const OmniPopupMenuItem({
    super.key,
    super.value,
    super.onTap,
    super.enabled = true,
    required super.child,
    this.selected = false,
    this.destructive = false,
  }) : super(height: OmniMenuStyle.minHeight, padding: EdgeInsets.zero);

  final bool selected;
  final bool destructive;

  @override
  PopupMenuItemState<T, OmniPopupMenuItem<T>> createState() =>
      _OmniPopupMenuItemState<T>();
}

class _OmniPopupMenuItemState<T>
    extends PopupMenuItemState<T, OmniPopupMenuItem<T>> {
  @override
  void handleTap() {
    if (ModalRoute.of(context)?.isCurrent != true) return;
    super.handleTap();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      role: SemanticsRole.menuItem,
      child: OmniMenuItem(
        enabled: widget.enabled,
        selected: widget.selected,
        destructive: widget.destructive,
        onTap: handleTap,
        child: widget.child ?? const SizedBox.shrink(),
      ),
    );
  }
}

/// Opaque popup surface. Its owner still controls positioning and animation.
class OmniMenuSurface extends StatelessWidget {
  const OmniMenuSurface({
    super.key,
    required this.child,
    this.padding = OmniMenuStyle.panelPadding,
    this.width,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: context.omniPalette.surfacePrimary,
        borderRadius: OmniMenuStyle.panelRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: context.isDarkTheme ? 0.20 : 0.06,
            ),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: OmniMenuStyle.panelRadius,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
