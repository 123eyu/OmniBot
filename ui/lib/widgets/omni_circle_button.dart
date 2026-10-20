import 'package:flutter/material.dart';
import 'package:ui/theme/theme_context.dart';

/// Shared round navigation control for the home, chat, and settings headers.
class OmniCircleButton extends StatelessWidget {
  const OmniCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 44,
    this.iconSize = 22,
    this.foregroundColor,
    this.tapTargetSize = MaterialTapTargetSize.shrinkWrap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color? foregroundColor;
  final MaterialTapTargetSize tapTargetSize;

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: palette.shadowColor,
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, size: iconSize),
        style: IconButton.styleFrom(
          foregroundColor: foregroundColor ?? palette.textPrimary,
          backgroundColor: palette.surfacePrimary,
          disabledBackgroundColor: palette.surfacePrimary,
          disabledForegroundColor: palette.textTertiary,
          fixedSize: Size.square(size),
          minimumSize: Size.square(size),
          maximumSize: Size.square(size),
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
          tapTargetSize: tapTargetSize,
        ),
      ),
    );
  }
}
