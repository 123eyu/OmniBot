import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:ui/theme/theme_context.dart';

/// A focused preview and action surface for the selected conversation.
/// The caller retains all action and conversation ownership.
class ConversationContextMenu extends StatelessWidget {
  const ConversationContextMenu({
    super.key,
    required this.anchor,
    required this.title,
    required this.actions,
  });

  final Rect anchor;
  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    final media = MediaQuery.of(context);
    final isDark = context.isDarkTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        const margin = 24.0;
        final width = math.min(400.0, constraints.maxWidth - margin * 2);
        final topInset = media.padding.top + 12;
        final bottomInset =
            math.max(media.padding.bottom, media.viewInsets.bottom) + 12;
        final shadow = [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.09),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ];
        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
                  ),
                ),
              ),
            ),
            CustomSingleChildLayout(
              delegate: _ConversationMenuLayout(
                anchor: anchor,
                width: width,
                topInset: topInset,
                bottomInset: bottomInset,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: SingleChildScrollView(
                  key: const ValueKey('conversation-context-scroll'),
                  clipBehavior: Clip.hardEdge,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        key: const ValueKey('conversation-context-preview'),
                        width: width,
                        constraints: const BoxConstraints(minHeight: 78),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 26,
                          vertical: 24,
                        ),
                        decoration: BoxDecoration(
                          color: palette.surfacePrimary,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: shadow,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: palette.borderStrong,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 17,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: math.min(width, 250),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: palette.surfacePrimary,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: shadow,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: actions,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ConversationMenuLayout extends SingleChildLayoutDelegate {
  const _ConversationMenuLayout({
    required this.anchor,
    required this.width,
    required this.topInset,
    required this.bottomInset,
  });

  final Rect anchor;
  final double width;
  final double topInset;
  final double bottomInset;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: math.max(0, constraints.maxHeight - topInset - bottomInset),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    return Offset(
      anchor.left.clamp(
        24.0,
        math.max(24.0, size.width - 24 - childSize.width),
      ),
      (anchor.top - 12).clamp(
        topInset,
        math.max(topInset, size.height - bottomInset - childSize.height),
      ),
    );
  }

  @override
  bool shouldRelayout(_ConversationMenuLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      width != oldDelegate.width ||
      topInset != oldDelegate.topInset ||
      bottomInset != oldDelegate.bottomInset;
}
