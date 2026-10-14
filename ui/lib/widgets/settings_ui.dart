import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ui/l10n/l10n.dart';
import 'package:ui/theme/theme_context.dart';

/// Unified surface decoration used across settings groups and cards.
///
/// Uses `palette.surfacePrimary` (#FFFFFF in light, #1C1E1F in dark) over
/// `palette.pageBackground` (#F4F7FB in light, #151617 in dark) with a
/// hairline subtle border and no drop shadow for a clean, restrained look.
BoxDecoration omniSettingsSurfaceDecoration(
  BuildContext context, {
  Color? color,
  Color? borderColor,
  double borderRadius = 16,
}) {
  final palette = context.omniPalette;
  final isDark = context.isDarkTheme;
  return BoxDecoration(
    color: color ?? palette.surfacePrimary,
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(
      color:
          borderColor ??
          palette.borderSubtle.withValues(alpha: isDark ? 0.65 : 0.85),
      width: 0.75,
    ),
  );
}

/// Unified surface shape used across settings groups and cards.
ShapeBorder omniSettingsSurfaceShape(
  BuildContext context, {
  Color? borderColor,
  double borderRadius = 16,
}) {
  final palette = context.omniPalette;
  final isDark = context.isDarkTheme;
  return RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(borderRadius),
    side: BorderSide(
      color:
          borderColor ??
          palette.borderSubtle.withValues(alpha: isDark ? 0.65 : 0.85),
      width: 0.75,
    ),
  );
}

/// A rounded, shadowless surface card for composite settings content
/// (forms, sliders, status banners, etc.).
class OmniSettingsCard extends StatelessWidget {
  const OmniSettingsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.color,
    this.borderColor,
    this.borderRadius = 16,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final double borderRadius;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    Widget card = Material(
      color: color ?? palette.surfacePrimary,
      shape: omniSettingsSurfaceShape(
        context,
        borderColor: borderColor,
        borderRadius: borderRadius,
      ),
      clipBehavior: clipBehavior,
      child: SizedBox(
        width: double.infinity,
        child: Padding(padding: padding, child: child),
      ),
    );
    if (margin != null) {
      card = Padding(padding: margin!, child: card);
    }
    return card;
  }
}

/// An inset grouped container that renders a vertical list of setting rows
/// inside a single rounded surface with subtle hairline dividers.
class OmniSettingsGroup extends StatelessWidget {
  const OmniSettingsGroup({
    super.key,
    required this.children,
    this.title,
    this.subtitle,
    this.headerTrailing,
    this.footer,
    this.dividerIndent = 46,
    this.dividerEndIndent = 16,
    this.borderRadius = 16,
    this.translateTitle = true,
  });

  final List<Widget> children;
  final String? title;
  final String? subtitle;
  final Widget? headerTrailing;
  final Widget? footer;
  final double dividerIndent;
  final double dividerEndIndent;
  final double borderRadius;
  final bool translateTitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    final isDark = context.isDarkTheme;
    final dividerColor = palette.borderSubtle.withValues(
      alpha: isDark ? 0.55 : 0.75,
    );

    final surface = Material(
      color: palette.surfacePrimary,
      shape: omniSettingsSurfaceShape(context, borderRadius: borderRadius),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                Divider(
                  height: 1,
                  thickness: 0.65,
                  indent: dividerIndent,
                  endIndent: dividerEndIndent,
                  color: dividerColor,
                ),
            ],
          ],
        ),
      ),
    );

    if (title == null && subtitle == null && footer == null) {
      return surface;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null || subtitle != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  headerTrailing == null
                      ? Text(
                          translateTitle ? context.trLegacy(title!) : title!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                            color: palette.textTertiary,
                            height: 1.35,
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Text(
                                translateTitle
                                    ? context.trLegacy(title!)
                                    : title!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                  color: palette.textTertiary,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            headerTrailing!,
                          ],
                        ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    translateTitle ? context.trLegacy(subtitle!) : subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: palette.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        surface,
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
            child: DefaultTextStyle(
              style: TextStyle(
                fontSize: 12,
                color: palette.textTertiary,
                height: 1.45,
              ),
              child: footer!,
            ),
          ),
      ],
    );
  }
}

/// A single row inside an [OmniSettingsGroup] or standalone settings list.
class OmniSettingsTile extends StatelessWidget {
  const OmniSettingsTile({
    super.key,
    this.tileKey,
    this.icon,
    this.iconColor,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.trailingTextColor,
    this.trailingStatusDotColor,
    this.trailing,
    this.onTap,
    this.showChevron,
    this.bottomNote,
    this.translateText = true,
    this.isDestructive = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 13.5),
  });

  final Key? tileKey;
  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final Color? trailingTextColor;
  final Color? trailingStatusDotColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool? showChevron;
  final String? bottomNote;
  final bool translateText;
  final bool isDestructive;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    final effectiveTitleColor = isDestructive
        ? const Color(0xFFE05252)
        : palette.textPrimary;
    final effectiveIconColor =
        iconColor ??
        (isDestructive
            ? const Color(0xFFE05252)
            : palette.textPrimary.withValues(alpha: 0.78));
    final hasLeading = leading != null || icon != null;
    final effectiveShowChevron =
        showChevron ?? (onTap != null && trailing == null);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: tileKey,
        onTap: onTap,
        splashColor: palette.accentPrimary.withValues(alpha: 0.06),
        highlightColor: palette.accentPrimary.withValues(alpha: 0.03),
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (hasLeading) ...[
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Center(
                        child:
                            leading ??
                            Icon(icon, size: 19, color: effectiveIconColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          translateText ? context.trLegacy(title) : title,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            color: effectiveTitleColor,
                            height: 1.38,
                          ),
                        ),
                        if (subtitle != null &&
                            subtitle!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2.5),
                          Text(
                            translateText
                                ? context.trLegacy(subtitle!)
                                : subtitle!,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    trailing!,
                  ] else if (trailingText != null || effectiveShowChevron) ...[
                    const SizedBox(width: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (trailingStatusDotColor != null) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: trailingStatusDotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (trailingText != null)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(
                              translateText
                                  ? context.trLegacy(trailingText!)
                                  : trailingText!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w400,
                                color:
                                    trailingTextColor ?? palette.textSecondary,
                              ),
                            ),
                          ),
                        if (trailingText != null && effectiveShowChevron)
                          const SizedBox(width: 4),
                        if (effectiveShowChevron)
                          Icon(
                            LucideIcons.chevronRight,
                            size: 16,
                            color: palette.textTertiary,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
              if (bottomNote != null && bottomNote!.trim().isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.only(top: 6, left: hasLeading ? 32 : 0),
                  child: Text(
                    translateText ? context.trLegacy(bottomNote!) : bottomNote!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: palette.textTertiary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Unified modern toggle switch for settings rows.
///
/// Wraps [FlutterSwitch] with balanced proportions (40x22, 16px thumb) and
/// theme-aware active/inactive colors.
class OmniSettingsSwitch extends StatelessWidget {
  const OmniSettingsSwitch({
    super.key,
    required this.value,
    required this.onToggle,
    this.enabled = true,
    this.duration = const Duration(milliseconds: 180),
  });

  final bool value;
  final ValueChanged<bool> onToggle;
  final bool enabled;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    final inactiveColor = context.isDarkTheme
        ? palette.borderStrong
        : const Color(0xFFD5DFEC);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => onToggle(!value) : null,
      child: AbsorbPointer(
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: FlutterSwitch(
            width: 40,
            height: 22,
            toggleSize: 16,
            padding: 3,
            activeColor: palette.accentPrimary,
            inactiveColor: inactiveColor,
            toggleColor: Colors.white,
            borderRadius: 999,
            duration: duration,
            value: value,
            onToggle: onToggle,
          ),
        ),
      ),
    );
  }
}

/// Minimalist status indicator: a 6px colored dot followed by a 12sp label.
class OmniSettingsStatusBadge extends StatelessWidget {
  const OmniSettingsStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.fontSize = 12,
  });

  final String label;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: color,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

/// Clean, pill-styled dropdown wrapper for inline setting row selections.
class OmniSettingsDropdown<T> extends StatelessWidget {
  const OmniSettingsDropdown({
    super.key,
    this.dropdownKey,
    required this.value,
    required this.items,
    required this.onChanged,
    this.maxWidth = 148,
  });

  final Key? dropdownKey;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.surfaceSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: palette.borderSubtle.withValues(
            alpha: context.isDarkTheme ? 0.5 : 0.7,
          ),
          width: 0.65,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          key: dropdownKey,
          value: value,
          isDense: true,
          isExpanded: true,
          borderRadius: BorderRadius.circular(14),
          dropdownColor: palette.surfacePrimary,
          elevation: 6,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
          icon: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              LucideIcons.chevronsUpDown,
              size: 14,
              color: palette.textTertiary,
            ),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Consistent input decoration for text fields inside settings cards.
InputDecoration omniSettingsInputDecoration(
  BuildContext context, {
  String? labelText,
  String? hintText,
  String? helperText,
  String? errorText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  bool isDense = true,
  EdgeInsetsGeometry? contentPadding,
}) {
  final palette = context.omniPalette;
  final isDark = context.isDarkTheme;
  final borderRadius = BorderRadius.circular(12);
  final borderColor = palette.borderSubtle.withValues(
    alpha: isDark ? 0.7 : 0.9,
  );

  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    helperText: helperText,
    helperMaxLines: 2,
    errorText: errorText,
    errorMaxLines: 2,
    isDense: isDense,
    filled: true,
    fillColor: palette.surfaceSecondary.withValues(alpha: isDark ? 0.65 : 0.7),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    labelStyle: TextStyle(
      color: palette.textSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
    hintStyle: TextStyle(color: palette.textTertiary, fontSize: 13),
    helperStyle: TextStyle(color: palette.textTertiary, fontSize: 11.5),
    contentPadding:
        contentPadding ??
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: borderColor, width: 0.75),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: borderColor, width: 0.75),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(
        color: borderColor.withValues(alpha: 0.4),
        width: 0.75,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(
        color: palette.accentPrimary.withValues(alpha: 0.75),
        width: 1.2,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: const BorderSide(color: Color(0xFFE05252), width: 0.9),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: const BorderSide(color: Color(0xFFE05252), width: 1.2),
    ),
  );
}
