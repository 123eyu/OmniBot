import 'package:flutter/material.dart';
import 'package:ui/theme/theme_context.dart';

/// Shared round navigation control for the home, chat, and settings headers.
class OmniCircleButton extends StatelessWidget {
  /// Shared with the chat header, including animated replacement icons.
  static const defaultIconSize = 20.0;

  const OmniCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 44,
    this.iconSize = defaultIconSize,
    this.foregroundColor,
    this.tapTargetSize = MaterialTapTargetSize.shrinkWrap,
    this.iconWidget,
    this.surfaceOpacity = 1,
  }) : assert(surfaceOpacity >= 0 && surfaceOpacity <= 1);

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color? foregroundColor;
  final MaterialTapTargetSize tapTargetSize;

  /// Allows an icon to morph without replacing the shared button or hit target.
  final Widget? iconWidget;

  /// Cross-fades the standard surface with a temporary transition shape.
  /// Ordinary buttons retain their original fill, shadow and press feedback.
  final double surfaceOpacity;

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    final surface = palette.surfacePrimary.withValues(
      alpha: palette.surfacePrimary.a * surfaceOpacity,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: palette.shadowColor.withValues(
              alpha: palette.shadowColor.a * surfaceOpacity,
            ),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        iconSize: iconSize,
        icon: iconWidget ?? Icon(icon),
        style: IconButton.styleFrom(
          foregroundColor: foregroundColor ?? palette.textPrimary,
          backgroundColor: surface,
          disabledBackgroundColor: surface,
          disabledForegroundColor: palette.textTertiary,
          fixedSize: Size.square(size),
          minimumSize: Size.square(size),
          maximumSize: Size.square(size),
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
          tapTargetSize: tapTargetSize,
          splashFactory: surfaceOpacity < 1 ? NoSplash.splashFactory : null,
        ),
      ),
    );
  }
}
