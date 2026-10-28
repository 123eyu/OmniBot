import 'package:flutter/material.dart';
import 'package:ui/theme/omni_theme_palette.dart';
import 'package:ui/theme/theme_context.dart';
import 'package:ui/widgets/flclash/liquid_glass.dart';

/// Shared dialog surface using the app's selected glass quality.
class OmniGlassPanel extends StatelessWidget {
  const OmniGlassPanel({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.padding = EdgeInsets.zero,
    this.width,
    this.height,
    this.forceDark = false,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;
  final bool forceDark;

  @override
  Widget build(BuildContext context) {
    if (LiquidGlassSurfaceScope.of(context)) {
      return SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Padding(padding: padding, child: child),
        ),
      );
    }
    final palette = forceDark ? OmniThemePalette.dark : context.omniPalette;
    final isDark = forceDark || context.isDarkTheme;
    if (LiquidGlassScope.of(context)) {
      final scheme = Theme.of(context).colorScheme;
      final resolvedScheme = forceDark
          ? scheme.copyWith(brightness: Brightness.dark)
          : scheme;
      return SizedBox(
        width: width,
        height: height,
        child: LiquidGlass(
          style: LiquidGlassStyle.alert(resolvedScheme),
          borderRadius: borderRadius,
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
    }
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: palette.surfacePrimary,
        borderRadius: borderRadius,
        border: Border.all(color: palette.borderSubtle, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: palette.shadowColor.withValues(alpha: isDark ? 0.22 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
