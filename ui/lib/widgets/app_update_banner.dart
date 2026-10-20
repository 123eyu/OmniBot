import 'package:flutter/material.dart';
import 'package:ui/theme/theme_context.dart';

class AppUpdateBanner extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  const AppUpdateBanner({
    super.key,
    required this.text,
    required this.onTap,
    this.onClose,
  });

  @override
  State<AppUpdateBanner> createState() => _AppUpdateBannerState();
}

class _AppUpdateBannerState extends State<AppUpdateBanner> {
  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(999),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: palette.surfaceSecondary,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: palette.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 14,
                    color: palette.textPrimary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      widget.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: palette.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (widget.onClose != null)
          Positioned(
            top: -6,
            right: -6,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onClose,
                customBorder: const CircleBorder(),
                child: Ink(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: palette.surfacePrimary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 13,
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
