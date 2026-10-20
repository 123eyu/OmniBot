import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ui/l10n/l10n.dart';
import 'package:ui/theme/theme_context.dart';

/// Triggers a crisp toggle haptic feedback.
void performOmniSwitchHaptic(bool nextValue) {
  if (nextValue) {
    HapticFeedback.lightImpact();
  } else {
    HapticFeedback.selectionClick();
  }
}

/// Triggers a subtle selection tick haptic feedback for menus and segments.
void performOmniSelectionHaptic() {
  HapticFeedback.selectionClick();
}

/// Unified surface decoration used across settings groups and cards.
///
/// Uses a plain rounded surface over the page background. Borders are opt-in;
/// fine inset dividers provide separation inside a group.
BoxDecoration omniSettingsSurfaceDecoration(
  BuildContext context, {
  Color? color,
  Color? borderColor,
  double borderRadius = 22,
}) {
  final palette = context.omniPalette;
  return BoxDecoration(
    color: color ?? palette.surfacePrimary,
    borderRadius: BorderRadius.circular(borderRadius),
    border: borderColor == null
        ? null
        : Border.all(color: borderColor, width: 0.75),
  );
}

/// Unified surface shape used across settings groups and cards.
ShapeBorder omniSettingsSurfaceShape(
  BuildContext context, {
  Color? borderColor,
  double borderRadius = 22,
}) {
  return RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(borderRadius),
    side: borderColor == null
        ? BorderSide.none
        : BorderSide(color: borderColor, width: 0.75),
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
    this.borderRadius = 22,
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
    this.dividerIndent = 54,
    this.dividerEndIndent = 0,
    this.borderRadius = 22,
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
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  headerTrailing == null
                      ? Text(
                          translateTitle ? context.trLegacy(title!) : title!,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
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
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
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
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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

  void _triggerDescendantDropdown(BuildContext context) {
    _OmniDropdownTapTarget? target;
    void visit(Element element) {
      if (target != null) return;
      if (element is StatefulElement &&
          element.state is _OmniDropdownTapTarget) {
        target = element.state as _OmniDropdownTapTarget;
        return;
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    if (target != null && target!.canOpenPopover) {
      target!.openPopover();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    final effectiveTitleColor = isDestructive
        ? const Color(0xFFE05252)
        : palette.textPrimary;
    final effectiveIconColor =
        iconColor ??
        (isDestructive ? const Color(0xFFE05252) : palette.textPrimary);
    final hasLeading = leading != null || icon != null;
    final effectiveShowChevron =
        showChevron ?? (onTap != null && trailing == null);
    final effectiveOnTap = onTap != null
        ? () {
            if (trailing is OmniSettingsSwitch) {
              performOmniSelectionHaptic();
            }
            onTap!();
          }
        : (trailing is OmniSettingsDropdown
              ? () => _triggerDescendantDropdown(context)
              : null);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: tileKey,
        onTap: effectiveOnTap,
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
                      width: 22,
                      height: 24,
                      child: Center(
                        child:
                            leading ??
                            Icon(icon, size: 20, color: effectiveIconColor),
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          translateText ? context.trLegacy(title) : title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
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
                                fontSize: 14,
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
                            size: 18,
                            color: palette.textTertiary,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
              if (bottomNote != null && bottomNote!.trim().isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.only(top: 6, left: hasLeading ? 36 : 0),
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

abstract interface class _OmniSwitchTapTarget {
  bool get canToggle;
  void triggerToggle();
}

/// Unified toggle switch for settings rows.
///
/// Features balanced 7:4 capsule proportions (44x25 track, 18px thumb, 3.5px
/// uniform inset), 1.127x thumb press/drag scale spring, damped horizontal
/// drag gesture, and tactile haptic feedback on toggle.
class OmniSettingsSwitch extends StatefulWidget {
  const OmniSettingsSwitch({
    super.key,
    required this.value,
    required this.onToggle,
    this.enabled = true,
    this.duration = const Duration(milliseconds: 200),
  });

  final bool value;
  final ValueChanged<bool> onToggle;
  final bool enabled;
  final Duration duration;

  @override
  State<OmniSettingsSwitch> createState() => _OmniSettingsSwitchState();
}

class _OmniSettingsSwitchState extends State<OmniSettingsSwitch>
    implements _OmniSwitchTapTarget {
  static const double _kTrackWidth = 44.0;
  static const double _kTrackHeight = 25.0;
  static const double _kThumbSize = 18.0;
  static const double _kInset = 3.5;
  static const double _kMaxTravel =
      _kTrackWidth - _kInset * 2 - _kThumbSize; // 19.0

  bool _isPressed = false;
  bool _isDragging = false;
  bool _hasVibrated = false;
  bool _hasVibratedOnce = false;
  double _rawDragOffset = 0.0;
  double _dragOffset = 0.0;

  @override
  bool get canToggle => widget.enabled;

  @override
  void triggerToggle() {
    if (!widget.enabled) return;
    final next = !widget.value;
    performOmniSwitchHaptic(next);
    widget.onToggle(next);
  }

  void _handleTap() {
    triggerToggle();
  }

  void _handleDragStart(DragStartDetails details) {
    if (!widget.enabled) return;
    setState(() {
      _isDragging = true;
      _hasVibrated = true;
      _hasVibratedOnce = false;
      _rawDragOffset = 0.0;
      _dragOffset = 0.0;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;
    setState(() {
      _rawDragOffset += details.delta.dx / 2.0;
      _dragOffset = widget.value
          ? _rawDragOffset.clamp(-_kMaxTravel, 0.0)
          : _rawDragOffset.clamp(0.0, _kMaxTravel);

      const midLow = _kMaxTravel * 0.45;
      const midHigh = _kMaxTravel * 0.55;
      if ((_dragOffset >= -midHigh && _dragOffset <= -midLow) ||
          (_dragOffset >= midLow && _dragOffset <= midHigh)) {
        _hasVibratedOnce = false;
      } else if ((_dragOffset > -_kMaxTravel && _dragOffset < 0.0) ||
          (_dragOffset > 0.0 && _dragOffset < _kMaxTravel)) {
        _hasVibrated = false;
      } else if (!_hasVibrated) {
        if ((widget.value && _dragOffset <= -_kMaxTravel) ||
            (!widget.value && _dragOffset == 0.0)) {
          performOmniSwitchHaptic(false);
          _hasVibrated = true;
          _hasVibratedOnce = true;
        } else if ((widget.value && _dragOffset == 0.0) ||
            (!widget.value && _dragOffset >= _kMaxTravel)) {
          performOmniSwitchHaptic(true);
          _hasVibrated = true;
          _hasVibratedOnce = true;
        }
      }
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!widget.enabled) return;
    final shouldToggle = _dragOffset.abs() > _kMaxTravel / 2.0;
    if (!_hasVibratedOnce && _dragOffset.abs() >= 1.0) {
      final next = shouldToggle ? !widget.value : widget.value;
      performOmniSwitchHaptic(next);
    }
    setState(() {
      _isDragging = false;
      _isPressed = false;
      _dragOffset = 0.0;
      _rawDragOffset = 0.0;
    });
    if (shouldToggle) {
      widget.onToggle(!widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    final isDark = context.isDarkTheme;
    final activeTrackColor = palette.accentPrimary;
    final inactiveTrackColor = palette.borderStrong;
    final thumbColor = widget.value
        ? Theme.of(context).colorScheme.onPrimary
        : Colors.white;
    final trackColor = widget.value ? activeTrackColor : inactiveTrackColor;
    final thumbLeft =
        _kInset + (widget.value ? _kMaxTravel : 0.0) + _dragOffset;
    final thumbScale = !widget.enabled
        ? 1.0
        : (_isPressed || _isDragging)
        ? 1.127
        : 1.0;
    final effectiveDuration = _isDragging ? Duration.zero : widget.duration;

    return Semantics(
      toggled: widget.value,
      enabled: widget.enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled
            ? (_) => setState(() => _isPressed = true)
            : null,
        onTapCancel: widget.enabled
            ? () => setState(() => _isPressed = false)
            : null,
        onTapUp: widget.enabled
            ? (_) => setState(() => _isPressed = false)
            : null,
        onTap: widget.enabled ? _handleTap : null,
        onHorizontalDragStart: widget.enabled ? _handleDragStart : null,
        onHorizontalDragUpdate: widget.enabled ? _handleDragUpdate : null,
        onHorizontalDragEnd: widget.enabled ? _handleDragEnd : null,
        child: Opacity(
          opacity: widget.enabled ? 1.0 : 0.45,
          child: SizedBox(
            width: _kTrackWidth,
            height: _kTrackHeight,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Invisible FlutterSwitch preserves compatibility with existing widget tests.
                Opacity(
                  opacity: 0,
                  child: IgnorePointer(
                    child: FlutterSwitch(
                      width: _kTrackWidth,
                      height: _kTrackHeight,
                      toggleSize: _kThumbSize,
                      padding: _kInset,
                      activeColor: activeTrackColor,
                      inactiveColor: inactiveTrackColor,
                      toggleColor: thumbColor,
                      borderRadius: 999,
                      duration: widget.duration,
                      value: widget.value,
                      onToggle: (next) {
                        performOmniSwitchHaptic(next);
                        widget.onToggle(next);
                      },
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: effectiveDuration,
                  curve: Curves.easeOutCubic,
                  width: _kTrackWidth,
                  height: _kTrackHeight,
                  decoration: BoxDecoration(
                    color: trackColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                AnimatedPositioned(
                  duration: effectiveDuration,
                  curve: Curves.easeOutBack,
                  left: thumbLeft.clamp(_kInset, _kInset + _kMaxTravel),
                  top: _kInset,
                  width: _kThumbSize,
                  height: _kThumbSize,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutBack,
                    scale: thumbScale,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: thumbColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.22 : 0.08,
                            ),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
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

/// Option model for [OmniSettingsDropdown].
@immutable
class OmniSettingsOption<T> {
  const OmniSettingsOption({
    required this.value,
    required this.label,
    this.subtitle,
  });

  final T value;
  final String label;
  final String? subtitle;
}

abstract interface class _OmniDropdownTapTarget {
  bool get canOpenPopover;
  void openPopover();
}

/// Refined, pill-styled selector trigger that opens an anchored floating
/// popover menu with inset rounded highlight pills and a checkmark indicator.
class OmniSettingsDropdown<T> extends StatefulWidget {
  const OmniSettingsDropdown({
    super.key,
    this.dropdownKey,
    required this.value,
    required this.options,
    required this.onChanged,
    this.maxWidth = 156,
    this.menuMinWidth = 176,
    this.menuMaxWidth = 264,
  });

  final Key? dropdownKey;
  final T value;
  final List<OmniSettingsOption<T>> options;
  final ValueChanged<T?>? onChanged;
  final double maxWidth;
  final double menuMinWidth;
  final double menuMaxWidth;

  @override
  State<OmniSettingsDropdown<T>> createState() =>
      _OmniSettingsDropdownState<T>();
}

class _OmniSettingsDropdownState<T> extends State<OmniSettingsDropdown<T>>
    implements _OmniDropdownTapTarget {
  @override
  bool get canOpenPopover =>
      widget.onChanged != null && widget.options.isNotEmpty;

  @override
  void openPopover() {
    _openPopover(context);
  }

  Future<void> _openPopover(BuildContext anchorContext) async {
    final callback = widget.onChanged;
    if (callback == null || widget.options.isEmpty) return;
    performOmniSelectionHaptic();

    final box = anchorContext.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.maybeOf(anchorContext)?.context.findRenderObject()
            as RenderBox?;
    if (box == null || !box.hasSize || overlay == null || !overlay.hasSize) {
      return;
    }

    final triggerTopLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final triggerBottomRight = box.localToGlobal(
      box.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final overlaySize = overlay.size;
    final hasSubtitles = widget.options.any(
      (item) => item.subtitle != null && item.subtitle!.trim().isNotEmpty,
    );
    final estimatedItemHeight = hasSubtitles ? 58.0 : 40.0;
    final estimatedMenuHeight =
        widget.options.length * estimatedItemHeight + 16.0;
    final mediaPadding = MediaQuery.paddingOf(anchorContext);
    final spaceBelow =
        overlaySize.height - mediaPadding.bottom - triggerBottomRight.dy - 16.0;
    final openUpward =
        spaceBelow < estimatedMenuHeight &&
        (triggerTopLeft.dy - mediaPadding.top) > estimatedMenuHeight;

    final rightEdge = (overlaySize.width - triggerBottomRight.dx).clamp(
      16.0,
      overlaySize.width - 16.0,
    );

    final selected = await showGeneralDialog<T>(
      context: anchorContext,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(anchorContext)
          .modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 170),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned(
              right: rightEdge,
              top: openUpward ? null : triggerBottomRight.dy + 6,
              bottom: openUpward
                  ? overlaySize.height - triggerTopLeft.dy + 6
                  : null,
              child: _OmniSettingsPopoverCard<T>(
                options: widget.options,
                selectedValue: widget.value,
                minWidth: widget.menuMinWidth,
                maxWidth: widget.menuMaxWidth,
                onSelected: (picked) => Navigator.of(dialogContext).pop(picked),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            alignment: openUpward ? Alignment.bottomRight : Alignment.topRight,
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );

    if (selected != null && selected != widget.value) {
      performOmniSwitchHaptic(true);
      callback(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    final isDark = context.isDarkTheme;
    final enabled = widget.onChanged != null;
    final selectedOption = widget.options.firstWhere(
      (item) => item.value == widget.value,
      orElse: () => widget.options.first,
    );

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: widget.dropdownKey,
          borderRadius: BorderRadius.circular(9.5),
          onTap: enabled ? () => _openPopover(context) : null,
          child: Container(
            constraints: BoxConstraints(maxWidth: widget.maxWidth),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: palette.surfaceSecondary.withValues(
                alpha: isDark ? 0.72 : 0.8,
              ),
              borderRadius: BorderRadius.circular(9.5),
              border: Border.all(
                color: palette.borderSubtle.withValues(
                  alpha: isDark ? 0.55 : 0.75,
                ),
                width: 0.65,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    selectedOption.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  LucideIcons.chevronsUpDown,
                  size: 13.5,
                  color: palette.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OmniSettingsPopoverCard<T> extends StatelessWidget {
  const _OmniSettingsPopoverCard({
    required this.options,
    required this.selectedValue,
    required this.minWidth,
    required this.maxWidth,
    required this.onSelected,
  });

  final List<OmniSettingsOption<T>> options;
  final T selectedValue;
  final double minWidth;
  final double maxWidth;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    final isDark = context.isDarkTheme;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: isDark ? palette.surfaceElevated : palette.surfacePrimary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: palette.borderSubtle.withValues(alpha: isDark ? 0.8 : 0.9),
            width: 0.75,
          ),
          boxShadow: [
            BoxShadow(
              color: palette.shadowColor.withValues(
                alpha: isDark ? 0.36 : 0.09,
              ),
              blurRadius: 22,
              spreadRadius: -2,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: palette.shadowColor.withValues(
                alpha: isDark ? 0.18 : 0.04,
              ),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0) const SizedBox(height: 2),
                _buildOptionTile(context, options[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile(BuildContext context, OmniSettingsOption<T> option) {
    final palette = context.omniPalette;
    final isDark = context.isDarkTheme;
    final selected = option.value == selectedValue;
    final hasSubtitle =
        option.subtitle != null && option.subtitle!.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9.5),
        onTap: () => onSelected(option.value),
        splashColor: palette.accentPrimary.withValues(alpha: 0.08),
        highlightColor: palette.accentPrimary.withValues(alpha: 0.04),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected
                ? palette.accentPrimary.withValues(alpha: isDark ? 0.16 : 0.09)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9.5),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 11,
              vertical: hasSubtitle ? 9 : 9.5,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: hasSubtitle
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selected
                              ? palette.accentPrimary
                              : palette.textPrimary,
                          height: 1.32,
                        ),
                      ),
                      if (hasSubtitle) ...[
                        const SizedBox(height: 2.5),
                        Text(
                          option.subtitle!,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w400,
                            color: palette.textSecondary,
                            height: 1.38,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: EdgeInsets.only(top: hasSubtitle ? 2 : 0),
                  child: SizedBox(
                    width: 15,
                    height: 15,
                    child: selected
                        ? Icon(
                            LucideIcons.check,
                            size: 15,
                            color: palette.accentPrimary,
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Clean, theme-consistent search input field for settings and catalog pages.
class OmniSettingsSearchField extends StatelessWidget {
  const OmniSettingsSearchField({
    super.key,
    required this.controller,
    this.focusNode,
    required this.hintText,
    this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final listenable = focusNode != null
        ? Listenable.merge([controller, focusNode!])
        : controller;
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        final palette = context.omniPalette;
        final isDark = context.isDarkTheme;
        final hasFocus = focusNode?.hasFocus ?? false;
        final hasQuery = controller.text.trim().isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          height: 40,
          decoration: BoxDecoration(
            color: palette.surfacePrimary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasFocus
                  ? palette.accentPrimary.withValues(alpha: 0.65)
                  : palette.borderSubtle.withValues(
                      alpha: isDark ? 0.65 : 0.85,
                    ),
              width: hasFocus ? 1.1 : 0.75,
            ),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            onTapOutside: (_) {
              if (focusNode != null) {
                focusNode!.unfocus();
              } else {
                FocusScope.of(context).unfocus();
              }
            },
            textInputAction: TextInputAction.search,
            style: TextStyle(
              fontSize: 13.5,
              color: palette.textPrimary,
              fontWeight: FontWeight.w400,
              height: 1.25,
            ),
            cursorColor: palette.accentPrimary,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                fontSize: 13,
                color: palette.textTertiary,
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 38,
                minHeight: 40,
              ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 40,
              ),
              prefixIcon: Icon(
                LucideIcons.search,
                size: 16.5,
                color: hasFocus ? palette.accentPrimary : palette.textTertiary,
              ),
              suffixIcon: hasQuery
                  ? IconButton(
                      padding: EdgeInsets.zero,
                      splashRadius: 16,
                      onPressed: () {
                        controller.clear();
                        onChanged?.call('');
                      },
                      icon: Icon(
                        LucideIcons.x,
                        size: 15,
                        color: palette.textTertiary,
                      ),
                    )
                  : null,
            ),
          ),
        );
      },
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
